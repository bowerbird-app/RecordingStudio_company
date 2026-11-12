# frozen_string_literal: true

module RecordingStudioCompany
  module Api
    module Errors
      module_function

      def wrap
        yield
      rescue RecordingStudioCompany::NotFound, RecordingStudioCompany::ParentNotAllowed => e
        raise ::RecordingStudioApi::NotFoundError, e.message
      rescue RecordingStudioCompany::NotAuthorized => e
        raise ::RecordingStudioApi::AuthorizationError, e.message
      rescue RecordingStudioCompany::Invalid, RecordingStudioCompany::CompanyAlreadyExists,
             RecordingStudioCompany::CompanyIntegrityError, RecordingStudioCompany::Trashed,
             RecordingStudioCompany::LogoRejected => e
        raise ::RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
