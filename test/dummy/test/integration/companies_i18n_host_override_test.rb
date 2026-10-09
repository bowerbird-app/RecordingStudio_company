# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class CompaniesI18nHostOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_STAYS_OFF =
    "HOST Adding a company stays off until the extra companies are moved or purged.".freeze

  GEM_STAYS_OFF =
    "Adding a company stays off until the extra companies are moved or purged.".freeze

  test "host config/locales English override wins on a real integrity page" do
    override_path = Rails.root.join("config/locales/company_host_override.en.yml")

    assert_path_exists override_path
    refute_includes File.read(override_path), "i18n.load_path"
    refute_includes File.read(override_path), "I18n.load_path"

    owner = User.create!(
      email: "company-i18n-host-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    newsroom = RecordingStudio.root_recording_for(PressCentre.create!(name: "Override Newsroom"))
    access = RecordingStudioAccessible.bootstrap_owner_access!(recording: newsroom, actor: owner)
    raise access.error if access.failure?

    Current.actor = owner
    RecordingStudioCompany.create(newsroom, actor: owner, name: "Nike, Inc.")
    second = RecordingStudio::Recording.new(
      root_recording: newsroom.root_recording,
      parent_recording: newsroom,
      recordable: RecordingStudioCompany::Company.create!(name: "Adidas AG")
    )
    second.save!(validate: false)

    sign_in owner
    get recording_studio_company.recording_companies_path(newsroom)

    assert_response :success
    body = css_select("main").text.squish
    assert_includes body, "Override Newsroom has 2 companies"
    assert_includes body, "This press centre holds one company."
    assert_includes body, HOST_STAYS_OFF
    refute_match(/(?<!HOST )#{Regexp.escape(GEM_STAYS_OFF)}/, body)
    assert_equal "Companies and organisations", css_select("h1").text.strip
  ensure
    Current.actor = nil
  end
end
