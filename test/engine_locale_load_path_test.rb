# frozen_string_literal: true

require "test_helper"

class EngineLocaleLoadPathTest < Minitest::Test
  def test_lib_ruby_files_do_not_append_to_i18n_load_path
    lib_files = Dir[File.expand_path("../lib/**/*.rb", __dir__)]

    assert_operator lib_files.length, :>, 0, "expected at least one .rb file under lib/"

    lib_files.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path",
                      "#{path} must not touch i18n.load_path (Rails engines already load config/locales)"
      refute_includes source, "I18n.load_path",
                      "#{path} must not touch I18n.load_path (Rails engines already load config/locales)"
    end
  end
end
