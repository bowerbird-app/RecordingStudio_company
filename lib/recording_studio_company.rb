# frozen_string_literal: true

# Attachable's services name ActiveRecord classes while they load.
require "active_record"
require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_attachable"
require "recording_studio_trashable"
require "flat_pack"
require "recording_studio_company/version"
require "recording_studio_company/configuration"
require "recording_studio_company/display_helper"
require "recording_studio_company/engine"

# Companies (corporate or legal organizations) under Recording Studio recordings.
#
# A company is a RecordingStudio::Recording whose recordable is a
# RecordingStudioCompany::Company snapshot. Public functions take and return
# company recordings. Store recording ids, never recordable ids.
#
# Reads do not authorize. Writes check Accessible (:edit on the parent for
# create, :edit on the company otherwise) and still pass the host's
# config.authorize_write inside RecordingStudio.record!.
# rubocop:disable-next Metrics/ModuleLength, Metrics/ClassLength
module RecordingStudioCompany
  COMPANY_TYPE = "RecordingStudioCompany::Company"
  LOGO_TYPE = "RecordingStudioAttachable::Attachment"
  LOGO_NAME = "logo"
  ACTIONS = %i[view create update trash restore].freeze
  private_constant :COMPANY_TYPE, :LOGO_TYPE, :LOGO_NAME, :ACTIONS

  class Error < StandardError; end
  class ParentNotAllowed < Error; end
  class NotAuthorized < Error; end
  class NotFound < Error; end
  class LogoRejected < Error; end

  class CompanyAlreadyExists < Error
    # The recording holding the parent's single company place. It may be trashed.
    attr_reader :company

    def initialize(company:)
      @company = company
      super("#{company.recordable.name} is already the company here")
    end
  end

  # A one-company parent holds more than one company recording, live or trashed.
  # Nothing picks one of them for the caller; the extras have to be moved or purged.
  class CompanyIntegrityError < Error
    attr_reader :companies

    def initialize(companies:)
      @companies = companies
      super("Only one company is allowed here, but #{companies.size} companies are recorded")
    end
  end

  class Invalid < Error
    # The unsaved RecordingStudioCompany::Company, with errors, for re-rendering a form.
    attr_reader :record

    def initialize(record:)
      @record = record
      super(record.errors.full_messages.to_sentence)
    end
  end

  class Trashed < Error
    attr_reader :company

    def initialize(company:)
      @company = company
      super("Restore #{company.recordable.name} before changing it")
    end
  end

  class ConfigurationError < ArgumentError; end
  class ManyCompaniesAllowed < ArgumentError; end

  class << self
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
      by_name(scope).preload(:recordable).to_a
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

    # Resolves a stored company recording id.
    def find(id, include_trashed: false)
      recording = RecordingStudio::Recording.unscoped.find_by(id:, recordable_type: COMPANY_TYPE) if id.present?
      raise NotFound, "No company #{id.inspect}" if recording.nil? || (recording.trashed_at && !include_trashed)

      recording
    end

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

    # The live logo attachment recording, or nil.
    def logo(company)
      logo = Slots.occupant(company!(company), LOGO_TYPE)
      logo if logo && logo.trashed_at.nil?
    end

    # Whether actor may take an action right now.
    #   :view    Accessible :view on the recording (a parent or a company)
    #   :create  the parent's type enables companies, the company place is free, and Accessible :edit
    #   :update  a live company and Accessible :edit
    #   :trash   a live company and Trashable's :trash authorization
    #   :restore a trashed company and Trashable's :restore authorization
    def can?(action, recording, actor:)
      unless ACTIONS.include?(action)
        raise ArgumentError, "Unknown action #{action.inspect}; expected one of #{ACTIONS.join(', ')}"
      end

      send(:"can_#{action}?", recording, actor)
    end

    private

    def can_view?(recording, actor) = allowed?(recording, :view, actor)

    def can_create?(parent, actor)
      allowance(parent).present? && Slots.vacant?(parent) && allowed?(parent, :edit, actor)
    end

    def can_update?(company, actor) = live_company?(company) && allowed?(company, :edit, actor)

    def can_trash?(company, actor)
      live_company?(company) && RecordingStudioTrashable.authorized?(action: :trash, actor:, recording: company)
    end

    def can_restore?(company, actor)
      company_recording?(company) && company.trashed_at.present? &&
        RecordingStudioTrashable.authorized?(action: :restore, actor:, recording: company)
    end

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

    # The company under parent whose "created" event carries key, or nil.
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

  # The one-or-many rule and the single-logo rule. Hosts cannot reach RecordingStudioCompany::Slots.
  #
  # A place under a parent holds at most one child recording of a type. Any such child occupies
  # it, live or trashed, until it is purged.
  #   RecordingStudioCompany::Company        under a parent whose type allows :one
  #   RecordingStudioAttachable::Attachment  under a company (the logo)
  module Slots
    ALLOWANCES = %i[one many].freeze
    MESSAGES = {
      company: "Only one company is allowed here",
      logo: "A company can have only one logo"
    }.freeze

    module_function

    # :one or :many. ConfigurationError for anything else, naming the type when known.
    def parse!(value, type: nil)
      allowance = value.to_s.strip.downcase.to_sym if value.is_a?(Symbol) || value.is_a?(String)
      return allowance if ALLOWANCES.include?(allowance)

      raise ConfigurationError,
            "Companies#{" on #{type}" if type} need allow: :one or allow: :many (got #{value.inspect})"
    end

    # Boot check run from the engine's to_prepare.
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

    # The child of type holding the place under parent: earliest created, trashed included.
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

    # :company, :logo, or nil for a new child of child_type under parent.
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

      # New recordings and moves. Revisions, trashing, and restoring never take a place.
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

  # Public only as RecordingStudio::Capabilities::Companies. It is defined in this lexical scope
  # so .to can reach the private Slots parser.
  companies_capability = Module.new do
    # include RecordingStudio::Capabilities::Companies.to(allow: :one) or .to(allow: :many)
    #   allow: :one  each recording of the including type holds at most one company, trashed included
    #   allow: :many no limit
    def self.to(**options)
      unknown = options.keys - [:allow]
      raise ConfigurationError, "Unknown companies option(s): #{unknown.join(', ')}" if unknown.any?

      RecordingStudio::Capabilities.include_for(:companies, allow: Slots.parse!(options[:allow]))
    end
  end
  unless RecordingStudio::Capabilities.const_defined?(:Companies, false)
    RecordingStudio::Capabilities.const_set(:Companies, companies_capability)
  end

  # Company is a capability-owned child: its allowed parents are the types that enable :companies.
  RecordingStudio.register_capability(:companies, source: "recording_studio_company", child_recordables: [COMPANY_TYPE])
end
