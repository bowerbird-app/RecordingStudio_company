# frozen_string_literal: true

module RecordingStudioCompany
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

    def company_home_path
      main_app.root_path if main_app.respond_to?(:root_path)
    end

    def company_parent_subtitle(parent)
      [parent.name, parent.type_label].compact_blank.uniq.join(" · ")
    end

    def company_field_error(record, field)
      record.errors.full_messages_for(field).to_sentence.presence
    end

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

    def company_logo_upload_options
      configured = RecordingStudio.capability_options(:attachable, for: Company.name).to_h
      LOGO_UPLOAD_OPTIONS.index_with do |option|
        configured.fetch(option) { RecordingStudioAttachable.configuration.public_send(option) }
      end
    end
  end
end
