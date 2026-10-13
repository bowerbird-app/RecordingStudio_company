# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# Render-level literal-English asserts for wave 2 controller copy. English
# output must match main. Does not rewrite existing tests to expect HOST strings
# except the dedicated boot-order guard for the rarely shown not-found title.
class CompaniesWave2I18nRenderTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_company_host.en.yml")
  HOST_NOT_FOUND = "HOST Not found"

  setup do
    @owner = User.create!(
      email: "company-wave2-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    @newsroom = RecordingStudio.root_recording_for(PressCentre.create!(name: "Wave2 Newsroom"))
    access = RecordingStudioAccessible.bootstrap_owner_access!(recording: @newsroom, actor: @owner)
    raise access.error if access.failure?

    Current.actor = @owner
    sign_in @owner
  end

  teardown do
    Current.actor = nil
  end

  test "creating a company renders literal english flash notice" do
    assert_difference -> { RecordingStudioCompany.companies(@newsroom).count }, 1 do
      post recording_studio_company.recording_companies_path(@newsroom), params: {
        idempotency_key: SecureRandom.uuid,
        company: { name: "Unilever" }
      }
    end

    company = RecordingStudioCompany.companies(@newsroom).sole
    assert_redirected_to recording_studio_company.company_path(company)
    assert_equal "Unilever was added.", flash[:notice]
  end

  test "logo form without a file renders literal english alert" do
    company = RecordingStudioCompany.create(@newsroom, actor: @owner, name: "Nike, Inc.")

    patch recording_studio_company.logo_company_path(company), params: { logo: { signed_blob_id: "" } }

    assert_redirected_to recording_studio_company.edit_company_path(company)
    assert_equal "Choose an image to upload.", flash[:alert]
  end

  test "unknown parent renders literal english page-missing description" do
    get recording_studio_company.recording_companies_path(SecureRandom.uuid)

    assert_response :not_found
    assert_includes css_select("main").text.squish, "This page doesn't exist, or you can't see it."
  end

  test "host boot-order override wins on rarely shown not-found title" do
    assert_path_exists BOOT_HOST_LOCALE
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_NOT_FOUND
    assert_equal HOST_NOT_FOUND, I18n.t("recording_studio.company.errors.not_found")

    get recording_studio_company.recording_companies_path(SecureRandom.uuid)

    assert_response :not_found
    assert_includes css_select("main").text.squish, HOST_NOT_FOUND
    assert_includes css_select("main").text.squish, "This page doesn't exist, or you can't see it."
  end
end
