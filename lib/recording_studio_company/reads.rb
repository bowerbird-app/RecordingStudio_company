# frozen_string_literal: true

module RecordingStudioCompany
  module Reads
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    # :one, :many, or nil when the parent's type does not enable companies.
    def allowance(parent)
      type = parent!(parent).recordable_type
      return unless RecordingStudio.capability_enabled?(:companies, for: type)

      Slots.parse!(RecordingStudio.capability_options(:companies, for: type).to_h[:allow], type:)
    end

    # Company recordings under parent, by name (case-insensitive), then created_at.
    def companies(parent, include_trashed: false)
      parent_not_allowed!(parent) unless allowance(parent)

      scope = Slots.children(parent, COMPANY_TYPE)
      scope = scope.where(trashed_at: nil) unless include_trashed
      by_name(scope).preload(:recordable)
    end

    # The company of a one-company parent, or nil. A trashed company is returned only with
    # include_trashed. Raises ManyCompaniesAllowed on a many-company parent and
    # CompanyIntegrityError when a one-company parent holds more than one company.
    def company(parent, include_trashed: false)
      case allowance(parent)
      when nil then parent_not_allowed!(parent)
      when :many then raise ManyCompaniesAllowed, "#{label_for(parent)} allows many companies; use companies(parent)"
      end

      occupant = Slots.sole_company!(parent)
      occupant if occupant && (include_trashed || occupant.trashed_at.nil?)
    end

    def find(id, include_trashed: false)
      recording = RecordingStudio::Recording.unscoped.find_by(id:, recordable_type: COMPANY_TYPE) if id.present?
      raise NotFound, "No company #{id.inspect}" if recording.nil? || (recording.trashed_at && !include_trashed)

      recording
    end

    # The live logo attachment recording, or nil.
    def logo(company)
      logo = Slots.occupant(company!(company), LOGO_TYPE)
      logo if logo && logo.trashed_at.nil?
    end
  end
  private_constant :Reads
end
