# frozen_string_literal: true

require "active_record"
require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_attachable"
require "recording_studio_trashable"
require "flat_pack"
require "recording_studio_company/version"
require "recording_studio_company/configuration"
require "recording_studio_company/copy"
require "recording_studio_company/display_helper"
require "recording_studio_company/slots"
require "recording_studio_company/helpers"
require "recording_studio_company/access"
require "recording_studio_company/reads"
require "recording_studio_company/writes"
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

  extend Helpers
  extend Access
  extend Reads
  extend Writes

  module Companies
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
    RecordingStudio::Capabilities.const_set(:Companies, Companies)
  end
  private_constant :Companies

  RecordingStudio.register_capability(:companies, source: "recording_studio_company", child_recordables: [COMPANY_TYPE])
end
