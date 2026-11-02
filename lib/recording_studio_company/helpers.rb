# frozen_string_literal: true

module RecordingStudioCompany
  module Helpers
    private

    def allowed?(recording, role, actor)
      return false if actor.nil?

      RecordingStudioAccessible.authorized?(actor:, recording:, role:)
    end

    def authorize!(recording, role, actor)
      return if allowed?(recording, role, actor)

      raise NotAuthorized, "Changing this #{label_for(recording).downcase} needs #{role} access"
    end

    def parent!(parent)
      return parent if parent.is_a?(RecordingStudio::Recording) && parent.persisted?

      raise ArgumentError, "Expected a persisted RecordingStudio::Recording, got #{parent.class}"
    end

    def company!(company)
      return company if company_recording?(company) && company.persisted?

      raise ArgumentError, "Expected a company recording; load one with RecordingStudioCompany.find(id)"
    end

    def company_recording?(recording)
      recording.is_a?(RecordingStudio::Recording) && recording.recordable_type == COMPANY_TYPE
    end

    def live_company?(recording) = company_recording?(recording) && recording.trashed_at.nil?

    def live_company_for_write!(company, actor)
      company!(company)
      authorize!(company, :edit, actor)
      current = RecordingStudio::Recording.unscoped.find(company.id)
      raise Trashed.new(company: current) if current.trashed_at

      current
    end

    def fields!(fields)
      unknown = fields.keys.map(&:to_sym) - Company::FIELDS
      raise ArgumentError, "Unknown company field(s): #{unknown.join(', ')}" if unknown.any?

      fields.transform_keys(&:to_sym)
    end

    def label_for(recording)
      RecordingStudio.recordable_type_label(recording.recordable_type)
    end

    def parent_not_allowed!(parent)
      raise ParentNotAllowed, "#{label_for(parent)} does not hold companies"
    end

    def by_name(scope)
      companies = Company.arel_table
      recordings = RecordingStudio::Recording.arel_table
      join = recordings.join(companies).on(companies[:id].eq(recordings[:recordable_id])).join_sources
      scope.joins(join).reorder(companies[:name].lower, recordings[:created_at], recordings[:id])
    end

    def created_with_key(parent, key)
      return if key.nil?

      recording_id = RecordingStudio::Event.where(
        recording_id: Slots.children(parent, COMPANY_TYPE).select(:id),
        action: "created",
        idempotency_key: key
      ).pick(:recording_id)
      RecordingStudio::Recording.unscoped.find(recording_id) if recording_id
    end

    # RecordingStudio.record! raises AuthorizationError when the host's config.authorize_write denies a write.
    def host_write
      yield
    rescue RecordingStudio::AuthorizationError => e
      raise NotAuthorized, e.message
    end
  end
  private_constant :Helpers
end
