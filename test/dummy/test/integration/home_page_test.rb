# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class HomePageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "home page links to the seeded company pages" do
    load Rails.root.join("db/seeds.rb").to_s
    sign_in User.find_by!(email: "admin@admin.com")
    press_centre = seeded_recording(PressCentre, "Nike Newsroom")
    agency = seeded_recording(Agency, "Northwind")
    project = seeded_recording(Project, "Harbour fit-out")
    nike = RecordingStudioCompany.company(press_centre)

    get root_path

    assert_response :success
    assert_select "h1", text: "Company demo"
    assert_select "a[href=?]", recording_studio_company.recording_companies_path(press_centre), text: "Open company"
    assert_select "a[href=?]", recording_studio_company.recording_companies_path(agency), text: "Open company list"
    assert_select "a[href=?]", recording_studio_company.recording_companies_path(project), text: "Open company"
    assert_select "a[href=?]", recording_studio_company.company_path(nike), text: "Nike, Inc."
    assert_select "img[alt=?]", "Nike, Inc. logo"
    assert_includes response.body, "Project in Northwind"
  ensure
    Current.actor = nil
  end

  test "home page explains how to add the demo records before the seeds run" do
    user = User.find_or_create_by!(email: "home-page-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in user

    get root_path

    assert_response :success
    assert_includes response.body, "No demo records yet"
  end

  private

  def seeded_recording(type, name)
    RecordingStudio::Recording.find_by!(recordable: type.find_by!(name: name))
  end
end
