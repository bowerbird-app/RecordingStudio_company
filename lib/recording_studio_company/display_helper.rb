# frozen_string_literal: true

module RecordingStudioCompany
  module DisplayHelper
    # The image is served by Attachable's preview route, so the viewer needs :view access.
    def recording_studio_company_logo(company, size: :md)
      name = company.recordable.name
      logo = RecordingStudioCompany.logo(company)
      variant = %i[xs sm md].include?(size.to_sym) ? :square_small : :square_med
      src = logo && authorized_attachment_preview_path(logo, variant)

      render FlatPack::Avatar::Component.new(src:, alt: "#{name} logo", name:, size:, shape: :rounded)
    end

    def recording_studio_company_card(company)
      render partial: "recording_studio_company/companies/card", locals: { company: }
    end
  end
end
