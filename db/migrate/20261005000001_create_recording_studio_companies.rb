# frozen_string_literal: true

# Company snapshots. Each edit inserts a new row through RecordingStudio revisions, so there is
# no unique key and no updated_at. Lookups reach companies through recording_studio_recordings.
class CreateRecordingStudioCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_companies, id: :uuid do |t|
      t.string :name, null: false
      t.string :legal_name
      t.text :description
      t.string :website_url
      t.string :email
      t.string :phone
      t.date :founded_on
      t.datetime :created_at, null: false
    end
  end
end
