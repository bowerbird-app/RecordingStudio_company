# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class CompaniesI18nHostOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_OVERRIDE_LOCALE = File.expand_path(
    "../locales/company_host_override.en.yml",
    __dir__
  ).freeze

  HOST_STAYS_OFF =
    "HOST Adding a company stays off until the extra companies are moved or purged.".freeze

  GEM_STAYS_OFF =
    "Adding a company stays off until the extra companies are moved or purged.".freeze

  setup do
    @original_load_path = I18n.load_path.dup
  end

  teardown do
    I18n.load_path.replace(@original_load_path)
    I18n.reload!
  end

  test "host locale file overrides gem english on a real integrity page" do
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

    with_host_override_locale do
      get recording_studio_company.recording_companies_path(newsroom)

      assert_response :success
      body = css_select("main").text.squish
      assert_includes body, "Override Newsroom has 2 companies"
      assert_includes body, "This press centre holds one company."
      assert_includes body, HOST_STAYS_OFF
      refute_match(/(?<!HOST )#{Regexp.escape(GEM_STAYS_OFF)}/, body)
      assert_equal "Companies and organisations", css_select("h1").text.strip
    end

    get recording_studio_company.recording_companies_path(newsroom)

    assert_response :success
    body = css_select("main").text.squish
    assert_includes body, GEM_STAYS_OFF
    refute_includes body, HOST_STAYS_OFF
    assert_equal @original_load_path, I18n.load_path
  ensure
    Current.actor = nil
  end

  private

  def with_host_override_locale
    original_load_path = I18n.load_path.dup
    expanded_override = File.expand_path(HOST_OVERRIDE_LOCALE)
    gem_locale = RecordingStudioCompany::Engine.root.join("config/locales/en.yml").to_s

    I18n.load_path |= [expanded_override]
    # Host override must win: append again so it is last even if already present.
    I18n.load_path.delete(expanded_override)
    I18n.load_path << expanded_override
    I18n.reload!

    expanded = I18n.load_path.map { |path| File.expand_path(path) }
    assert_operator expanded.index(expanded_override), :>, expanded.index(File.expand_path(gem_locale))

    yield
  ensure
    I18n.load_path.replace(original_load_path)
    I18n.reload!
  end
end
