# frozen_string_literal: true

require "uri"

module RecordingStudioCompany
  class Company < ApplicationRecord
    self.table_name = "recording_studio_companies"
    self.record_timestamps = false

    FIELDS = %i[name legal_name description website_url email phone founded_on].freeze

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

    def website_href
      return if website_url.blank?

      candidate = website_url.match?(/\A[a-z][a-z0-9+.-]*:/i) ? website_url : "https://#{website_url}"
      uri = URI.parse(candidate)
      candidate if uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      nil
    end

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
