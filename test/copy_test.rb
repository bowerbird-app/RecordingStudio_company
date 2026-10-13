# frozen_string_literal: true

require "test_helper"

class CopyTest < Minitest::Test
  def test_user_message_maps_known_english_literals_with_defaults
    with_gem_locale_loaded do
      I18n.with_locale(:en) do
        assert_equal "A company can't be added here.",
                     RecordingStudioCompany::Copy.user_message("A company can't be added here.")
        assert_equal "Nike, Inc. was added.",
                     RecordingStudioCompany::Copy.user_message("Nike, Inc. was added.")
        assert_equal "Only one company is allowed here, but 2 companies are recorded",
                     RecordingStudioCompany::Copy.user_message(
                       "Only one company is allowed here, but 2 companies are recorded"
                     )
        assert_equal "Only one company is allowed here",
                     RecordingStudioCompany::Copy.user_message("Only one company is allowed here")
        assert_equal "A company can have only one logo",
                     RecordingStudioCompany::Copy.user_message("A company can have only one logo")
      end
    end
  end

  def test_user_message_passes_unknown_english_through_byte_for_byte
    unknown = "Attachable rejected this upload for a host reason"
    assert_equal unknown, RecordingStudioCompany::Copy.user_message(unknown)
  end

  def test_user_message_maps_under_non_english_locale_with_english_default
    with_gem_locale_loaded do
      original_locales = I18n.available_locales
      I18n.available_locales = original_locales | %i[en fr]
      I18n.with_locale(:fr) do
        assert_equal "Nike, Inc. was added.",
                     RecordingStudioCompany::Copy.user_message("Nike, Inc. was added.")
        assert_equal "Not found",
                     RecordingStudioCompany::Copy.t("errors.not_found", default: "Not found")
      end
    ensure
      I18n.available_locales = original_locales
    end
  end

  def test_t_resolves_flash_keys_to_english
    with_gem_locale_loaded do
      I18n.with_locale(:en) do
        assert_equal "The logo was updated.",
                     RecordingStudioCompany::Copy.t("flashes.logo_updated", default: "The logo was updated.")
        assert_equal "Edit Nike, Inc.",
                     RecordingStudioCompany::Copy.t(
                       "titles.edit_with_name",
                       name: "Nike, Inc.",
                       default: "Edit Nike, Inc."
                     )
      end
    end
  end

  private

  def with_gem_locale_loaded
    original_load_path = I18n.load_path.dup
    locale_path = File.expand_path("../config/locales/en.yml", __dir__)
    I18n.load_path |= [File.expand_path(locale_path)]
    I18n.reload!
    yield
  ensure
    I18n.load_path.replace(original_load_path)
    I18n.reload!
  end
end
