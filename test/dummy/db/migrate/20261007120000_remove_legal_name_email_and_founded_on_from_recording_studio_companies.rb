# frozen_string_literal: true

class RemoveLegalNameEmailAndFoundedOnFromRecordingStudioCompanies < ActiveRecord::Migration[8.1]
  def change
    remove_column :recording_studio_companies, :legal_name, :string
    remove_column :recording_studio_companies, :email, :string
    remove_column :recording_studio_companies, :founded_on, :date
  end
end
