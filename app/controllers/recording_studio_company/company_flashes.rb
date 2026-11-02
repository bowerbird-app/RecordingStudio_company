# frozen_string_literal: true

module RecordingStudioCompany
  module CompanyFlashes
    private

    def flash_cant_add
      company_copy("flashes.cant_add", default: "A company can't be added here.")
    end

    def flash_was_added(company)
      name = company.recordable.name
      company_copy("flashes.was_added", name:, default: "#{name} was added.")
    end

    def flash_was_saved(company)
      name = company.recordable.name
      company_copy("flashes.was_saved", name:, default: "#{name} was saved.")
    end

    def flash_in_trash(company)
      name = company.recordable.name
      company_copy("flashes.in_trash", name:, default: "#{name} is in the trash.")
    end

    def flash_was_restored(company)
      name = company.recordable.name
      company_copy("flashes.was_restored", name:, default: "#{name} was restored.")
    end

    def flash_cant_edit(company)
      name = company.recordable.name
      company_copy("flashes.cant_edit", name:, default: "You can't edit #{name}.")
    end

    def flash_choose_image
      company_copy("flashes.choose_image", default: "Choose an image to upload.")
    end

    def flash_logo_updated
      company_copy("flashes.logo_updated", default: "The logo was updated.")
    end

    def flash_logo_removed
      company_copy("flashes.logo_removed", default: "The logo was removed.")
    end
  end
end
