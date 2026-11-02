# frozen_string_literal: true

require "active_support/concern"

module RecordingStudioCompany
  module Slots
    ALLOWANCES = %i[one many].freeze
    MESSAGES = {
      company: "Only one company is allowed here",
      logo: "A company can have only one logo"
    }.freeze

    module_function

    def parse!(value, type: nil)
      allowance = value.to_s.strip.downcase.to_sym if value.is_a?(Symbol) || value.is_a?(String)
      return allowance if ALLOWANCES.include?(allowance)

      raise ConfigurationError,
            "Companies#{" on #{type}" if type} need allow: :one or allow: :many (got #{value.inspect})"
    end

    def verify!
      RecordingStudio.recordable_declarations
      unless RecordingStudio.configuration.recordable_types.include?(COMPANY_TYPE)
        raise ConfigurationError, %(Add "#{COMPANY_TYPE}" to config.recordable_types)
      end

      RecordingStudio.configuration.enabled_recordable_types_for(:companies).each do |type|
        if RecordingStudio.shared_root_type?(type)
          raise ConfigurationError, "#{type} is a shared root and cannot hold companies"
        end

        parse!(RecordingStudio.capability_options(:companies, for: type).to_h[:allow], type:)
      end
    end

    # Unscoped, so a host default_scope on recordings cannot hide an occupant.
    def children(parent, type)
      RecordingStudio::Recording.unscoped.where(parent_recording_id: parent.id, recordable_type: type)
    end

    def occupant(parent, type, except: nil)
      scope = children(parent, type)
      scope = scope.where.not(id: except) if except
      scope.reorder(:created_at, :id).first
    end

    def sole_company!(parent)
      occupants = children(parent, COMPANY_TYPE).reorder(:created_at, :id).to_a
      raise CompanyIntegrityError.new(companies: occupants) if occupants.size > 1

      occupants.first
    end

    def vacant?(parent)
      RecordingStudioCompany.allowance(parent) == :many || occupant(parent, COMPANY_TYPE).nil?
    end

    # Locks the parent's root, then the parent: the order RecordingStudio.record! uses when it
    # creates a child, so taking these locks first never inverts it. Returns the locked parent.
    def lock_parent!(parent)
      root_id = parent.root_recording_id
      RecordingStudio::Recording.unscoped.lock.find(root_id) if root_id.present? && root_id != parent.id
      RecordingStudio::Recording.unscoped.lock.find(parent.id)
    end

    def slot_for(child_type, parent)
      case child_type
      when COMPANY_TYPE then :company if RecordingStudioCompany.allowance(parent) == :one
      when LOGO_TYPE then :logo if parent.recordable_type == COMPANY_TYPE
      end
    end

    # Included into RecordingStudio::Recording by the engine. Runs inside record!'s transaction,
    # after record! has locked the root and the parent.
    module Validation
      extend ActiveSupport::Concern

      included do
        validate :recording_studio_company_slot_free, if: :recording_studio_company_slot_candidate?
      end

      private

      def recording_studio_company_slot_candidate?
        parent_recording_id.present? && [COMPANY_TYPE, LOGO_TYPE].include?(recordable_type) &&
          (new_record? || will_save_change_to_parent_recording_id?)
      end

      def recording_studio_company_slot_free
        parent = RecordingStudio::Recording.unscoped.find_by(id: parent_recording_id)
        slot = parent && Slots.slot_for(recordable_type, parent)
        return unless slot

        # Inside record! these locks are already held. A raw create! or a move takes them here,
        # so the occupancy read waits for a concurrent writer under the same parent.
        Slots.lock_parent!(parent)
        return unless Slots.occupant(parent, recordable_type, except: id)

        errors.add(:base, :"#{slot}_taken", message: MESSAGES.fetch(slot))
      end
    end
  end
  private_constant :Slots
end
