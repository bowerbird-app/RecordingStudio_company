# frozen_string_literal: true

# Removing a logo trashes the attachment recording so the logo place stays taken.
# Enable Trashable on Attachable's type in the host. The company gem does not patch it.
Rails.application.config.to_prepare do
  next unless defined?(RecordingStudioAttachable::Attachment)
  next if RecordingStudio.capability_enabled?(:trashable, for: "RecordingStudioAttachable::Attachment")

  RecordingStudioAttachable::Attachment.include(RecordingStudio::Capabilities::Trashable.to)
end
