# frozen_string_literal: true

require "recording_studio"
require "recording_studio_company/version"
require "recording_studio_company/engine"
require "recording_studio_company/configuration"

module RecordingStudioCompany
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end
