# frozen_string_literal: true

require "test_helper"

class ApiSourceTest < Minitest::Test
  def test_register_has_one_api_availability_check
    source = File.read(File.expand_path("../lib/recording_studio_company/api.rb", __dir__))

    assert_equal 1, source.scan("defined?(::RecordingStudioApi)").size
    refute_includes source, "const_set"
    refute_includes source, "remove_const"
  end

  def test_engine_registers_the_api_after_reload
    names = RecordingStudioCompany::Engine.initializers.map(&:name)

    assert_includes names, "recording_studio_company.api"
  end
end
