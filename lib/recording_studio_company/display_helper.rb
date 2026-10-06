# frozen_string_literal: true

module RecordingStudioCompany
  # View helpers for showing a company on any page, without the management pages.
  # The engine includes them into ActionView.
  module DisplayHelper
    # The company's live logo as a FlatPack avatar, or the initials of its name when it has no logo.
    # The image is served by Attachable's preview route, so the viewer needs :view access.
    def recording_studio_company_logo(company, size: :md)
      name = company.recordable.name
      logo = RecordingStudioCompany.logo(company)
      variant = %i[xs sm md].include?(size.to_sym) ? :square_small : :square_med
      src = logo && authorized_attachment_preview_path(logo, variant)

      render FlatPack::Avatar::Component.new(src:, alt: "#{name} logo", name:, size:, shape: :rounded)
    end

    # A read-only profile: logo, name, legal name when it differs from the name, description,
    # website, email, phone, and founded date. Blank fields are left out.
    def recording_studio_company_card(company)
      render partial: "recording_studio_company/companies/card", locals: { company: }
    end
  end
end
