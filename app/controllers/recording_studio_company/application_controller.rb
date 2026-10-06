# frozen_string_literal: true

module RecordingStudioCompany
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    include RecordingStudio::UsesDefaultLayout

    # UsesDefaultLayout does nothing when the host controller already includes it, and the host may
    # pick another layout for its own pages, so the company pages set both explicitly.
    layout "recording_studio/default_layout"
    helper RecordingStudio::LayoutHelper
    helper RecordingStudioCompany::CompaniesHelper

    protect_from_forgery with: :exception

    rescue_from NotFound, ParentNotAllowed, with: :render_not_found
    rescue_from NotAuthorized, with: :render_forbidden
    rescue_from Trashed, with: :redirect_to_trashed_company

    helper_method :company_can?

    private

    def current_company_actor
      return ::Current.actor if defined?(::Current) && ::Current.respond_to?(:actor) && ::Current.actor

      current_user if respond_to?(:current_user, true)
    end

    def company_can?(action, recording)
      RecordingStudioCompany.can?(action, recording, actor: current_company_actor)
    end

    def authorize_company!(action, recording)
      return if company_can?(action, recording)

      raise NotAuthorized, "#{action.to_s.capitalize} is not allowed for #{recording.recordable.name}"
    end

    def string_param(*path)
      value = path.reduce(params) { |scope, key| scope[key] if scope.is_a?(ActionController::Parameters) }
      value.presence if value.is_a?(String)
    end

    def render_not_found
      render_error :not_found, title: "Not found", description: "This page doesn't exist, or you can't see it."
    end

    def render_forbidden
      render_error :forbidden, title: "Not allowed", description: "You don't have permission to make this change."
    end

    def render_error(status, title:, description:)
      @error_title = title
      @error_description = description
      render "recording_studio_company/companies/error", status:
    end

    def redirect_to_trashed_company(error)
      redirect_to company_path(error.company), alert: error.message, status: :see_other
    end
  end
end
