# frozen_string_literal: true

require "uri"

module RecordingStudioCompany
  # One immutable snapshot of a company's fields. Edits insert a new row through
  # RecordingStudio revisions, so the table has no unique business key and no updated_at.
  class Company < ApplicationRecord
    self.table_name = "recording_studio_companies"
    self.record_timestamps = false

    # The single field list. Strong params, unknown-field checks, and update's change check use it.
    FIELDS = %i[name legal_name description website_url email phone founded_on].freeze

    # The only length map. Validations and form maxlength attributes read it.
    LIMITS = {
      name: 200,
      legal_name: 255,
      description: 5_000,
      website_url: 2_048,
      email: 320,
      phone: 50
    }.freeze

    recording_studio_recordable label: "Company", plural_label: "Companies", root: false

    include RecordingStudio::Capabilities::Trashable.to
    include RecordingStudio::Capabilities::Attachable.to(
      allowed_content_types: ["image/*"],
      enabled_attachment_kinds: [:image],
      max_file_size: 10.megabytes,
      max_file_count: 1,
      auth_roles: { upload: :edit, revise: :edit, remove: :edit, restore: :edit }
    )

    normalizes(*LIMITS.keys, with: ->(value) { value.to_s.strip.presence })

    validates :name, presence: true
    LIMITS.each { |field, maximum| validates field, length: { maximum: }, allow_nil: true }
    validate :founded_on_must_be_a_date

    before_create { self.created_at ||= Time.current }

    # An http(s) URL for website_url, or nil when it cannot be linked safely. A bare host such as
    # "nike.com" links as "https://nike.com"; "javascript:alert(1)" gives nil. The stored value is unchanged.
    def website_href
      return if website_url.blank?

      candidate = website_url.match?(/\A[a-z][a-z0-9+.-]*:/i) ? website_url : "https://#{website_url}"
      uri = URI.parse(candidate)
      candidate if uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      nil
    end

    # "tel:" with the phone's leading "+" and digits, or nil when it has fewer than three digits.
    def phone_href
      digits = phone.to_s.gsub(/\D/, "")
      return if digits.length < 3

      "tel:#{'+' if phone.start_with?('+')}#{digits}"
    end

    private

    # Blank means unknown. Input that does not cast to a date is an error instead of being dropped.
    def founded_on_must_be_a_date
      errors.add(:founded_on, :invalid) if founded_on.nil? && founded_on_before_type_cast.present?
    end
  end
end
