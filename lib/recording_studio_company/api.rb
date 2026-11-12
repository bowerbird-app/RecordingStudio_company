# frozen_string_literal: true

require_relative "api/company_resource"
require_relative "api/logo_actions"

module RecordingStudioCompany
  module Api
    TYPE = "RecordingStudioCompany::Company"

    module_function

    def register!(apis: [:public])
      return unless defined?(::RecordingStudioApi)

      Array(apis).each { |api| register_api(api) }
    end

    def register_api(api)
      register_type(api)
      register_resource_handlers(api)
      LogoActions.register!(api)
    end

    def register_type(api)
      return if ::RecordingStudioApi.recordable_registration_for(TYPE, api:)

      ::RecordingStudioApi.register_recordable_type_api(TYPE, **type_options(api))
    end

    def type_options(api)
      {
        api:,
        operations: %i[index show create update],
        auto_capability_actions: false,
        capability_actions: %i[set_logo remove_logo],
        serializer: method(:serialize_fields),
        output_keys: Company::FIELDS,
        writable_attributes: Company::FIELDS
      }
    end

    def register_resource_handlers(api)
      {
        index: CompanyResource::Index,
        show: CompanyResource::Show,
        create: CompanyResource::Create,
        update: CompanyResource::Update
      }.each do |action, handler|
        next if ::RecordingStudioApi.resource_handler(TYPE, action, api:)

        ::RecordingStudioApi.register_resource_handler(TYPE, action, api:, handler:)
      end
    end

    def serialize_fields(company, **)
      Company::FIELDS.index_with { |field| company.public_send(field) }
    end
  end
end
