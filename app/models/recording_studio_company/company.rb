# frozen_string_literal: true

require "uri"

module RecordingStudioCompany
  class Company < ApplicationRecord
    self.table_name = "recording_studio_companies"
    self.record_timestamps = false

    FIELDS = %i[name description website_url].freeze

    LIMITS = {
      name: 200,
      description: 5_000,
      website_url: 2_048
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

    before_create { self.created_at ||= Time.current }

    def website_href
      return if website_url.blank?

      candidate = website_url.match?(/\A[a-z][a-z0-9+.-]*:/i) ? website_url : "https://#{website_url}"
      uri = URI.parse(candidate)
      candidate if uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      nil
    end
  end
end
