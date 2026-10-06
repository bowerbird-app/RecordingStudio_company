class PressCentre < ApplicationRecord
  recording_studio_recordable label: "Press centre", plural_label: "Press centres", root: true
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)
  include RecordingStudio::Capabilities::Companies.to(allow: :one)
end
