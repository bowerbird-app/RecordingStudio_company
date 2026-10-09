# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < Minitest::Test
  # I18n interpolation tokens use %{name}; Style/FormatStringToken wants %<name>s.
  # rubocop:disable-next Style/FormatStringToken
  COMPANY_KEYS = {
    "navigation" => {
      "back" => "Back",
      "home" => "Home"
    },
    "titles" => {
      "index" => "Companies and organisations",
      "add" => "Add company",
      "edit" => "Edit company",
      "edit_with_name" => "Edit %{name}"
    },
    "actions" => {
      "add_company" => "Add company",
      "add_company_plus" => "+ Company",
      "edit_company" => "Edit company",
      "save" => "Save",
      "cancel" => "Cancel",
      "delete" => "Delete",
      "restore" => "Restore",
      "restore_company" => "Restore company",
      "restore_aria" => "Restore %{name}",
      "view" => "View",
      "view_aria" => "View %{name}",
      "view_company" => "View company",
      "change_logo" => "Change logo",
      "upload_logo" => "Upload logo",
      "remove_logo" => "Remove logo"
    },
    "labels" => {
      "name" => "Name",
      "website" => "Website",
      "description" => "Description"
    },
    "placeholders" => {
      "website" => "https://example.com"
    },
    "empty" => {
      "no_company_title" => "No company yet",
      "no_company_description" => "This %{type} holds one company.",
      "no_companies_title" => "No companies yet",
      "no_companies_description" => "Companies added to %{name} are listed here."
    },
    "trash" => {
      "in_trash_title" => "%{name} is in the trash",
      "restore_hint" => "Restore it to change it again.",
      "vacancy_description" => "This %{type} holds one company. Restore %{name} to use it again.",
      "section_title" => "In trash",
      "section_subtitle" => "Restore a company to list it again.",
      "in_trash_suffix" => " (in the trash)"
    },
    "integrity" => {
      "title" => "%{name} has %{count} companies",
      "holds_one" => "This %{type} holds one company.",
      "stays_off" => "Adding a company stays off until the extra companies are moved or purged."
    },
    "form" => {
      "save_failed_title" => "The company could not be saved"
    },
    "new" => {
      "logo_hint" => "You can add a logo after the company is saved."
    },
    "logo" => {
      "alt" => "%{name} logo"
    }
  }.freeze

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_english_company_keys_resolve_without_missing_translations
    with_gem_locale_loaded do
      I18n.with_locale(:en) do
        each_leaf_key(COMPANY_KEYS) do |parts, english|
          full_key = "recording_studio.company.#{parts.join('.')}"
          translation = I18n.t(full_key, default: nil)

          assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
          assert_equal english, I18n.t(full_key, raise: true)
        end

        assert_equal "Edit Nike, Inc.",
                     I18n.t("recording_studio.company.titles.edit_with_name", name: "Nike, Inc.")
        assert_equal "Nike Newsroom has 2 companies",
                     I18n.t("recording_studio.company.integrity.title", name: "Nike Newsroom", count: 2)
        assert_equal "Nike, Inc. logo",
                     I18n.t("recording_studio.company.logo.alt", name: "Nike, Inc.")
      end
    end
  end

  def test_en_yml_nests_keys_under_recording_studio_company
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("company")

    assert_equal COMPANY_KEYS, deep_stringify(tree)
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_path
    File.join(engine_locales_dir, "en.yml")
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end

  def deep_stringify(value)
    case value
    when Hash then value.to_h { |key, child| [key.to_s, deep_stringify(child)] }
    else value
    end
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
