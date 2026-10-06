# frozen_string_literal: true

require "uri"

module RecordingStudioCompany
  # Helpers for the company management pages. Pages elsewhere use DisplayHelper.
  module CompaniesHelper
    LOGO_UPLOAD_CONTROLLER = "recording-studio-attachable--attachment-revision-upload"
    LOGO_UPLOAD_OPTIONS = %i[
      allowed_content_types
      max_file_size
      image_processing_enabled
      image_processing_max_width
      image_processing_max_height
      image_processing_quality
    ].freeze

    # The host's root path, when it has one.
    def company_home_path
      main_app.root_path if main_app.respond_to?(:root_path)
    end

    # "Nike Newsroom · Press centre"
    def company_parent_subtitle(parent)
      [parent.name, parent.type_label].compact_blank.uniq.join(" · ")
    end

    # "about.nike.com" for a website that can be linked, otherwise nil.
    def company_website_host(record)
      href = record.website_href
      URI.parse(href).host if href
    end

    def company_field_error(record, field)
      record.errors.full_messages_for(field).to_sentence.presence
    end

    def company_list_name(company)
      tag.div(class: "flex items-center gap-3") do
        safe_join([
                    recording_studio_company_logo(company, size: :sm),
                    link_to(company.recordable.name, company_path(company), class: "font-medium")
                  ])
      end
    end

    def company_list_actions(company)
      name = company.recordable.name
      buttons = [company_list_button("View", company_path(company), "View #{name}")]
      if company_can?(:update, company)
        buttons << company_list_button("Edit", edit_company_path(company), "Edit #{name}")
      end
      tag.div(safe_join(buttons), class: "flex justify-end gap-2")
    end

    # Data attributes for Attachable's revision upload Stimulus controller on the logo form.
    # It uploads the chosen image directly, then submits the form with logo[signed_blob_id].
    def company_logo_form_data
      options = company_logo_upload_options
      values = {
        direct_upload_url: main_app.rails_direct_uploads_path,
        signed_blob_field_name: "logo[signed_blob_id]",
        auto_submit: true,
        **options.except(:allowed_content_types)
      }
      prefix = LOGO_UPLOAD_CONTROLLER.tr("-", "_")

      { controller: LOGO_UPLOAD_CONTROLLER, action: "submit->#{LOGO_UPLOAD_CONTROLLER}#handleSubmit" }
        .merge(values.compact.transform_keys { |key| :"#{prefix}_#{key}_value" })
    end

    def company_logo_accept
      Array(company_logo_upload_options[:allowed_content_types]).join(",")
    end

    private

    def company_list_button(text, href, label)
      render FlatPack::Button::Component.new(text:, style: :ghost, size: :sm, href:, aria: { label: })
    end

    # Company's Attachable options, falling back to Attachable's configuration.
    def company_logo_upload_options
      configured = RecordingStudio.capability_options(:attachable, for: Company.name).to_h
      LOGO_UPLOAD_OPTIONS.index_with do |option|
        configured.fetch(option) { RecordingStudioAttachable.configuration.public_send(option) }
      end
    end
  end
end
