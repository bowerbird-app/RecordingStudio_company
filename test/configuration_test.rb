# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioCompany::Configuration.new
  end

  def test_new_configuration_has_core_hooks_only
    assert_instance_of RecordingStudio::Hooks, @configuration.hooks
    assert_equal [:hooks_registered], @configuration.to_h.keys
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(api_key: "ignored", "timeout" => 7)

    refute_respond_to @configuration, :api_key
    refute_respond_to @configuration, :timeout
  end

  def test_merge_with_non_enumerable_is_noop
    before = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal before, @configuration.to_h
  end

  def test_merge_calls_setters_that_exist
    configuration = Class.new(RecordingStudioCompany::Configuration) { attr_accessor :label }.new

    configuration.merge!("label" => "Companies")

    assert_equal "Companies", configuration.label
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudioCompany.configure

    assert_kind_of RecordingStudioCompany::Configuration, RecordingStudioCompany.configuration
  end
end
