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

    def company_list_name(company)
      tag.div(class: "flex items-center gap-3") do
        safe_join([
                    recording_studio_company_logo(company, size: :sm),
                    link_to(company.recordable.name, company_path(company), class: "font-medium")
                  ])
      end
    end

    def company_list_actions(company)
      tag.div(class: "flex justify-end") do
        render FlatPack::Button::Dropdown::Component.new(**company_actions_menu(company)) do |dropdown|
          company_action_items(dropdown, company)
        end
      end
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

    def company_actions_menu(company)
      {
        text: "",
        icon: "dots",
        style: :ghost,
        size: :sm,
        show_chevron: false,
        placement: :bottom_right,
        trigger_attributes: { aria: { label: "Actions for #{company.recordable.name}" } }
      }
    end

    def company_action_items(dropdown, company)
      dropdown.menu_item(text: "View", icon: "eye", href: company_path(company))
      return unless company_can?(:update, company)

      dropdown.menu_item(text: "Edit", icon: "pencil", href: edit_company_path(company))
    end

    def company_logo_upload_options
      configured = RecordingStudio.capability_options(:attachable, for: Company.name).to_h
      LOGO_UPLOAD_OPTIONS.index_with do |option|
        configured.fetch(option) { RecordingStudioAttachable.configuration.public_send(option) }
      end
    end
  end
end
