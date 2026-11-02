# frozen_string_literal: true

module RecordingStudioCompany
  module Writes
    # Records a new company under parent. Raises ParentNotAllowed, NotAuthorized, Invalid, or
    # CompanyAlreadyExists. A one-company parent that holds a company, live or trashed, rejects
    # the second create instead of returning the first.
    #
    # Within one parent, an idempotency_key that already created a company returns that company,
    # even if it was trashed since.
    def create(parent, actor:, idempotency_key: nil, **fields)
      parent_not_allowed!(parent) unless allowance(parent)
      attributes = fields!(fields)
      authorize!(parent, :edit, actor)

      host_write { create_company!(parent, attributes, actor:, key: idempotency_key.presence) }
    rescue ActiveRecord::RecordInvalid => e
      create_failed!(parent, e)
    end

    # Revises the given fields through RecordingStudio's revise. When nothing changes it records
    # nothing and returns the same recording. Raises NotAuthorized, Trashed, or Invalid.
    def update(company, actor:, **fields)
      company!(company)
      attributes = fields!(fields)
      authorize!(company, :edit, actor)

      host_write { update_company!(company, attributes, actor:) }
    rescue ActiveRecord::RecordInvalid => e
      raise Invalid.new(record: e.record) if e.record.is_a?(Company)

      raise
    end

    # Sets the company's single logo. Replaces the existing logo's file, restoring the logo if it
    # was removed, and never adds a second attachment. Raises NotAuthorized, Trashed, or LogoRejected.
    #
    # No locks are taken here. The first logo goes through record!, which locks the root and then
    # the company; a replacement keeps Attachable's own lock order.
    def set_logo(company, signed_blob_id:, actor:)
      current = live_company_for_write!(company, actor)

      host_write do
        RecordingStudio::Recording.transaction do
          existing = Slots.occupant(current, LOGO_TYPE)
          existing ? replace_logo!(existing, signed_blob_id, actor) : upload_logo!(current, signed_blob_id, actor)
        end
      end
      current
    rescue RecordingStudioAttachable::StorageLimitError => e
      raise LogoRejected, e.message
    end

    # Removes the logo through Attachable, which trashes it. The trashed logo keeps the logo place,
    # so the next set_logo revives the same attachment recording. Without a live logo this is a no-op.
    def remove_logo(company, actor:)
      current = live_company_for_write!(company, actor)
      logo = Slots.occupant(current, LOGO_TYPE)
      return current if logo.nil? || logo.trashed_at

      host_write do
        RecordingStudio::Recording.transaction do
          result = RecordingStudioAttachable::Services::RemoveAttachment.call(attachment_recording: logo, actor:)
          raise LogoRejected, result.error if result.failure?
        end
      end
      current
    end

    private

    def create_company!(parent, attributes, actor:, key:)
      RecordingStudio::Recording.transaction do
        Slots.lock_parent!(parent)
        created_with_key(parent, key) || record_company!(parent, attributes, actor:, key:)
      end
    end

    def update_company!(company, attributes, actor:)
      RecordingStudio::Recording.transaction do
        locked = RecordingStudio::Recording.unscoped.lock.find(company.id)
        raise Trashed.new(company: locked) if locked.trashed_at

        revise_company!(locked, attributes, actor:)
      end
    end

    def record_company!(parent, attributes, actor:, key:)
      RecordingStudio.record!(
        action: "created",
        recordable: Company.new(attributes),
        root_recording: parent.root_recording_or_self,
        parent_recording: parent,
        actor:,
        idempotency_key: key
      ).recording
    end

    def create_failed!(parent, error)
      record = error.record
      raise Invalid.new(record:) if record.is_a?(Company)

      occupant = record.errors.of_kind?(:base, :company_taken) && Slots.sole_company!(parent)
      raise CompanyAlreadyExists.new(company: occupant) if occupant

      raise error
    end

    def revise_company!(locked, attributes, actor:)
      current = locked.recordable
      candidate = RecordingStudio.duplicate_recordable(current)
      candidate.assign_attributes(attributes)
      raise Invalid.new(record: candidate) unless candidate.valid?
      return locked if Company::FIELDS.all? { |field| candidate.public_send(field) == current.public_send(field) }

      locked.root_recording_or_self.revise(locked, actor:) { |recordable| recordable.assign_attributes(attributes) }
    end

    def upload_logo!(company, signed_blob_id, actor)
      result = RecordingStudioAttachable::Services::RecordAttachmentUpload.call(
        parent_recording: company, signed_blob_id:, actor:, name: LOGO_NAME
      )
      raise LogoRejected, result.error if result.failure?
    end

    def replace_logo!(logo, signed_blob_id, actor)
      result = RecordingStudioAttachable::Services::ReplaceAttachmentFile.call(
        attachment_recording: logo, signed_blob_id:, actor:, name: LOGO_NAME
      )
      raise LogoRejected, result.error if result.failure?
      return unless logo.trashed_at

      restored = RecordingStudioAttachable::Services::RestoreAttachment.call(attachment_recording: logo.reload, actor:)
      raise LogoRejected, restored.error if restored.failure?
    end
  end
  private_constant :Writes
end
