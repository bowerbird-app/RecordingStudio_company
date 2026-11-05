# frozen_string_literal: true

RecordingStudioCompany.configure do |config|
  # nil uses RecordingStudio.configuration.layout, then recording_studio/default_layout.
  # Pass a layout name, false, or a callable that accepts controller:.
  # config.layout = nil
end
