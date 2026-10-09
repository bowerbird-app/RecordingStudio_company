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
    end
  end

  test "host config/locales override wins for the integrity stays_off key" do
    override_path = Rails.root.join("config/locales/company_host_override.en.yml")

    assert_path_exists override_path, "expected host override file in test/dummy/config/locales/"
    refute_includes File.read(override_path), "I18n.load_path"
    assert_equal(
      "HOST Adding a company stays off until the extra companies are moved or purged.",
      I18n.t("recording_studio.company.integrity.stays_off", raise: true)
    )
    assert_equal(
      "This press centre holds one company.",
      I18n.t("recording_studio.company.integrity.holds_one", type: "press centre", raise: true)
    )
  end
end
