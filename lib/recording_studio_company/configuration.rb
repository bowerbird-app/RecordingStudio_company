# frozen_string_literal: true

module RecordingStudioCompany
  class Configuration
    attr_reader :hooks, :layout

    def initialize
      @hooks = RecordingStudio::Hooks.new
      @layout = nil
    end

    def layout=(value)
      @layout = RecordingStudio::Layout.accept(value)
    end

    def to_h
      {
        hooks_registered: hooks.registered_counts
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
    end
  end
end
