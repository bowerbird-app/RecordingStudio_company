# frozen_string_literal: true

require "test_helper"
require "action_controller"

class EngineTest < Minitest::Test
  ProbeConfiguration = Class.new(RecordingStudioCompany::Configuration) do
    attr_accessor :label, :timeout
  end

  def test_before_and_after_initialize_initializers_run_hooks
    with_probe_configuration do |config|
      before_called = false
      after_called = false

      config.hooks.before_initialize { |_engine| before_called = true }
      config.hooks.after_initialize { |_engine| after_called = true }

      find_initializer("recording_studio_company.before_initialize").block.call(Object.new)
      find_initializer("recording_studio_company.after_initialize").block.call(Object.new)

      assert before_called
      assert after_called
    end
  end

  def test_load_config_merges_config_sources_and_runs_on_configuration_hook
    with_probe_configuration do |config|
      hook_called = false
      hook_payload = nil
      config.hooks.on_configuration do |cfg|
        hook_called = true
        hook_payload = cfg
      end

      app = config_app(x_config: { label: "from_x" }, yaml: { label: "from_yaml", timeout: 12 })

      find_initializer("recording_studio_company.load_config").block.call(app)

      assert hook_called
      assert_equal config, hook_payload
      assert_equal "from_x", config.label
      assert_equal 12, config.timeout
    end
  end

  def test_load_config_skips_a_missing_yaml_file
    with_probe_configuration do |config|
      app = config_app(x_config: { timeout: 15 })

      find_initializer("recording_studio_company.load_config").block.call(app)

      assert_equal 15, config.timeout
      assert_nil config.label
    end
  end

  def test_load_config_ignores_config_that_is_not_a_hash
    with_probe_configuration do |config|
      app = config_app(x_config: Object.new, yaml: "from_yaml")

      find_initializer("recording_studio_company.load_config").block.call(app)

      assert_nil config.label
      assert_nil config.timeout
    end
  end

  def test_load_config_is_noop_without_config_sources
    with_probe_configuration do |config|
      app = Struct.new(:config).new(Object.new)

      find_initializer("recording_studio_company.load_config").block.call(app)

      assert_nil config.label
      assert_nil config.timeout
    end
  end

  def test_apply_extension_initializers_register_active_support_on_load_callbacks
    to_prepare_blocks = []
    config_stub = Object.new
    config_stub.define_singleton_method(:to_prepare) do |&block|
      to_prepare_blocks << block
    end

    RecordingStudioCompany::Engine.stub(:config, config_stub) do
      find_initializer("recording_studio_company.apply_model_extensions").block.call
      find_initializer("recording_studio_company.apply_controller_extensions").block.call
    end

    assert_equal 2, to_prepare_blocks.size
  end

  def test_model_extension_initializer_skips_abstract_models
    to_prepare_blocks = capture_to_prepare("recording_studio_company.apply_model_extensions")

    abstract_model = Class.new do
      def self.abstract_class?
        true
      end
    end
    concrete_model = Class.new do
      def self.abstract_class?
        false
      end
    end
    applied = []

    RecordingStudioCompany::Engine.stub(:apply_model_extensions, ->(model) { applied << model }) do
      ActiveRecord::Base.stub(:descendants, [abstract_model, concrete_model]) do
        to_prepare_blocks.first.call
      end
    end

    assert_equal [concrete_model], applied
  end

  def test_controller_extension_initializer_applies_all_controllers
    to_prepare_blocks = capture_to_prepare("recording_studio_company.apply_controller_extensions")

    first_controller = Class.new
    second_controller = Class.new
    applied = []

    RecordingStudioCompany::Engine.stub(:apply_controller_extensions, ->(controller) { applied << controller }) do
      ActionController::Base.stub(:descendants, [first_controller, second_controller]) do
        to_prepare_blocks.first.call
      end
    end

    assert_equal [first_controller, second_controller], applied
  end

  def test_apply_model_extensions_adds_registered_methods_once
    with_probe_configuration do |config|
      model_class = Class.new do
        def self.name
          "ExampleRecord"
        end
      end

      config.hooks.extend_model(:ExampleRecord) do
        def template_extension_method
          :applied
        end
      end

      RecordingStudioCompany::Engine.apply_model_extensions(model_class)
      RecordingStudioCompany::Engine.apply_model_extensions(model_class)

      instance = model_class.new
      assert_equal :applied, instance.template_extension_method
    end
  end

  def test_apply_model_extensions_applies_the_same_registered_block_once
    with_probe_configuration do |config|
      model_class = Class.new do
        def self.name
          "ExampleRecord"
        end
      end

      runs = 0
      extension = proc do
        runs += 1
        def template_extension_method
          :applied
        end
      end

      config.hooks.extend_model(:ExampleRecord, &extension)
      config.hooks.extend_model(:ExampleRecord, &extension)
      RecordingStudioCompany::Engine.apply_model_extensions(model_class)
      RecordingStudioCompany::Engine.apply_model_extensions(model_class)

      assert_equal 1, runs
      assert_equal :applied, model_class.new.template_extension_method
    end
  end

  def test_apply_controller_extensions_matches_demodulized_name
    with_probe_configuration do |config|
      controller_class = Class.new do
        def self.name
          "Admin::DashboardController"
        end
      end

      config.hooks.extend_controller(:DashboardController) do
        def template_controller_extension
          :applied
        end
      end

      RecordingStudioCompany::Engine.apply_controller_extensions(controller_class)

      instance = controller_class.new
      assert_equal :applied, instance.template_controller_extension
    end
  end

  private

  def with_probe_configuration
    probe = ProbeConfiguration.new
    RecordingStudioCompany.stub(:configuration, probe) { yield probe }
  ensure
    probe&.hooks&.clear!
  end

  def capture_to_prepare(initializer_name)
    to_prepare_blocks = []
    config_stub = Object.new
    config_stub.define_singleton_method(:to_prepare) do |&block|
      to_prepare_blocks << block
    end

    RecordingStudioCompany::Engine.stub(:config, config_stub) do
      find_initializer(initializer_name).block.call
    end

    to_prepare_blocks
  end

  def find_initializer(name)
    RecordingStudioCompany::Engine.initializers.find { |initializer| initializer.name == name }
  end

  def config_app(x_config:, yaml: nil)
    dir = nil
    if yaml
      dir = Dir.mktmpdir
      File.write(File.join(dir, "recording_studio_company.yml"), "")
    end

    xcfg = Struct.new(:recording_studio_company).new(x_config)
    app = Struct.new(:config).new(Struct.new(:x).new(xcfg))
    app.define_singleton_method(:paths) do
      dir ? { "config" => Struct.new(:existent).new([dir]) } : {}
    end
    app.define_singleton_method(:config_for) { |_name| yaml }
    app
  end
end
