# frozen_string_literal: true

require "i18n"

module RecordingStudioCompany
  # Rails I18n lookups for Company user-facing copy outside views. Every call
  # passes an English `default:` so a host locale without a fallback never shows
  # "translation missing". Keys live under `recording_studio.company.*`.
  #
  # Lib return values and raised exception messages stay main's English
  # literals. Controllers and views call `user_message` to map those known
  # English strings to locale keys at render time.
  module Copy
    PREFIX = "recording_studio.company"

    STATIC_MESSAGE_KEYS = {
      "Only one company is allowed here" => "messages.company_taken",
      "A company can have only one logo" => "messages.logo_taken",
      "A company can't be added here." => "flashes.cant_add",
      "Choose an image to upload." => "flashes.choose_image",
      "The logo was updated." => "flashes.logo_updated",
      "The logo was removed." => "flashes.logo_removed",
      "Not found" => "errors.not_found",
      "This page doesn't exist, or you can't see it." => "errors.page_missing",
      "Not allowed" => "errors.not_allowed",
      "You don't have permission to make this change." => "errors.forbidden_description"
    }.freeze

    NAME_MESSAGE_PATTERNS = [
      [/\A(.+) was added\.\z/, "flashes.was_added", :name],
      [/\A(.+) was saved\.\z/, "flashes.was_saved", :name],
      [/\A(.+) is in the trash\.\z/, "flashes.in_trash", :name],
      [/\A(.+) was restored\.\z/, "flashes.was_restored", :name],
      [/\AYou can't edit (.+)\.\z/, "flashes.cant_edit", :name],
      [/\A(.+) is already the company here\z/, "flashes.already_company", :name],
      [/\ARestore (.+) before changing it\z/, "flashes.restore_before_change", :name]
    ].freeze

    COUNT_MESSAGE_PATTERNS = [
      [
        /\AOnly one company is allowed here, but (\d+) companies are recorded\z/,
        "flashes.integrity_recorded",
        :count
      ]
    ].freeze

    module_function

    def t(key, **)
      I18n.t("#{PREFIX}.#{key}", **)
    end

    # Map a lib/exception English message to a locale string at render time.
    # Unknown messages pass through byte-for-byte.
    def user_message(message)
      english = message.to_s
      return english if english.blank?

      return t(STATIC_MESSAGE_KEYS[english], default: english) if STATIC_MESSAGE_KEYS.key?(english)

      mapped = translate_pattern_message(english, NAME_MESSAGE_PATTERNS)
      return mapped if mapped

      mapped = translate_count_message(english)
      return mapped if mapped

      english
    end

    def translate_pattern_message(english, patterns)
      patterns.each do |pattern, key, capture|
        match = pattern.match(english)
        next unless match

        value = match[1]
        return t(key, capture => value, default: english)
      end
      nil
    end

    def translate_count_message(english)
      COUNT_MESSAGE_PATTERNS.each do |pattern, key, capture|
        match = pattern.match(english)
        next unless match

        count = Integer(match[1], 10)
        return t(key, capture => count, default: english)
      end
      nil
    end
    private_class_method :translate_pattern_message, :translate_count_message
  end
end
