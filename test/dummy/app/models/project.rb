class Project < ApplicationRecord
  recording_studio_recordable label: "Project", root: false, allowed_parent_types: [ "Agency" ]
  include RecordingStudio::Capabilities::Companies.to(allow: :one)
end
