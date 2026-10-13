class HomeController < ApplicationController
  SEEDED_COMPANY_PARENTS = [
    [ "PressCentre", "Nike Newsroom" ],
    [ "Agency", "Northwind" ],
    [ "Project", "Harbour fit-out" ]
  ].freeze

  def index
    @company_parents = SEEDED_COMPANY_PARENTS.filter_map { |type, name| seeded_recording(type, name) }
  end

  private

  def seeded_recording(type, name)
    RecordingStudio::Recording
      .where(RecordingStudio::Recording.recording_studio_trashable_kept_sql)
      .find_by(
        recordable_type: type,
        recordable_id: type.constantize.where(name: name).select(:id)
      )
  end
end
