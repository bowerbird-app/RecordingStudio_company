# frozen_string_literal: true

require "test_helper"

class LocalesTest < ActiveSupport::TestCase
  test "rails i18n load path includes the gem english locale file" do
    locale_path = RecordingStudioCompany::Engine.root.join("config/locales/en.yml")

    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, locale_path.to_s
  end

  test "company interface keys resolve to english in the host app" do
    I18n.with_locale(:en) do
      assert_equal "Companies and organisations",
                   I18n.t("recording_studio.company.titles.index", raise: true)
      assert_equal "+ Company",
                   I18n.t("recording_studio.company.actions.add_company_plus", raise: true)
      assert_equal "No company yet",
                   I18n.t("recording_studio.company.empty.no_company_title", raise: true)
      assert_equal "Nike, Inc. logo",
                   I18n.t("recording_studio.company.logo.alt", name: "Nike, Inc.", raise: true)
      assert_equal(
        "Adding a company stays off until the extra companies are moved or purged.",
        I18n.t("recording_studio.company.integrity.stays_off", raise: true)
      )
    end
  end

  test "test-only host override is not on the default rails load path" do
    override_path = File.expand_path("locales/company_host_override.en.yml", __dir__)
    expanded = I18n.load_path.map { |path| File.expand_path(path) }

    assert_path_exists override_path
    refute_includes expanded, File.expand_path(override_path)
  end

  test "boot-loaded host override for rarely shown not-found title is on the rails load path" do
    boot_override = Rails.root.join("config/locales/recording_studio_company_host.en.yml")
    expanded = I18n.load_path.map { |path| File.expand_path(path) }

    assert_path_exists boot_override
    assert_includes expanded, boot_override.to_s
    assert_equal "HOST Not found", I18n.t("recording_studio.company.errors.not_found", raise: true)
    assert_equal "This page doesn't exist, or you can't see it.",
                 I18n.t("recording_studio.company.errors.page_missing", raise: true)
  end
end

