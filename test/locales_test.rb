# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < Minitest::Test
  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_english_company_keys_resolve_without_missing_translations
    with_gem_locale_loaded do
      I18n.with_locale(:en) do
        each_leaf_key(company_keys) do |parts, english|
          full_key = "recording_studio.company.#{parts.join('.')}"
          translation = I18n.t(full_key, default: nil)

          assert_equal english, translation, "#{full_key} should resolve to the shipped English copy"
          assert_equal english, I18n.t(full_key, raise: true)
        end

        assert_equal "Edit Nike, Inc.",
                     I18n.t("recording_studio.company.titles.edit_with_name", name: "Nike, Inc.")
        assert_equal "Nike Newsroom has 2 companies",
                     I18n.t("recording_studio.company.integrity.title", name: "Nike Newsroom", count: 2)
        assert_equal "Nike, Inc. logo",
                     I18n.t("recording_studio.company.logo.alt", name: "Nike, Inc.")
        assert_equal "Nike, Inc. was added.",
                     I18n.t("recording_studio.company.flashes.was_added", name: "Nike, Inc.")
        assert_equal "Only one company is allowed here, but 2 companies are recorded",
                     I18n.t("recording_studio.company.flashes.integrity_recorded", count: 2)
      end
    end
  end

  def test_en_yml_nests_keys_under_recording_studio_company
    assert_equal(
      %w[
        navigation titles actions labels placeholders empty trash integrity form new logo flashes errors messages
      ],
      company_keys.keys
    )
  end

  private

  def company_keys
    locale_tree(locale_path, "en").fetch("recording_studio").fetch("company")
  end

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_path
    File.join(engine_locales_dir, "en.yml")
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end

  def each_leaf_key(tree, parts = [], &block)
    tree.each do |key, value|
      next_parts = parts + [key]
      if value.is_a?(Hash)
        each_leaf_key(value, next_parts, &block)
      else
        yield next_parts, value
      end
    end
  end

  def with_gem_locale_loaded
    original_load_path = I18n.load_path.dup
    expanded = File.expand_path(locale_path)
    I18n.load_path |= [expanded]
    I18n.reload!
    yield
  ensure
    I18n.load_path.replace(original_load_path)
    I18n.reload!
  end
end
