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

  # The live recording db/seeds.rb created, or nil before the seeds have run.
  def seeded_recording(type, name)
    RecordingStudio::Recording.find_by(
      recordable_type: type,
      recordable_id: type.constantize.where(name: name).select(:id),
      trashed_at: nil
    )
  end
end
