class PressCentre < ApplicationRecord
  recording_studio_recordable label: "Press centre", plural_label: "Press centres", root: true
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
  RecordingStudio.enable_capability(:api_access_point, on: self) if defined?(RecordingStudioApi)
  include RecordingStudio::Capabilities::Companies.to(allow: :one)
end
