# frozen_string_literal: true

require "test_helper"
require "zlib"

class CompaniesApiTest < ActionDispatch::IntegrationTest
  BASE = "/recording_studio_api/api/v1"

  setup do
    @previous_actor = Current.actor
    @owner = user("owner")
    @editor = user("editor")
    @viewer = user("viewer")
    Current.actor = @owner
    @newsroom = owned_root(PressCentre.create!(name: "API Newsroom #{SecureRandom.hex(4)}"))
    @agency = owned_root(Agency.create!(name: "API Agency #{SecureRandom.hex(4)}"))
    @stranger = user("stranger")
    @other = owned_root(PressCentre.create!(name: "Other newsroom #{SecureRandom.hex(4)}"), actor: @stranger)
    @editor_access = grant!(@newsroom, @editor, :edit)
    @viewer_access = grant!(@newsroom, @viewer, :view)
    grant!(@agency, @editor, :edit)
    @editor_token, @editor_client = token_for(@editor_access)
    @viewer_token, = token_for(@viewer_access)
  end

  teardown { Current.actor = @previous_actor }

  test "index show create and update go through company reads and writes" do
    listed = call(:get, "/companies", @editor_token, parent_id: @newsroom.id)
    assert_response :success, response.body
    assert_equal [], listed.fetch("records")

    created = call(:post, "/companies", @editor_token, parent_id: @newsroom.id, name: "Acme Coffee Pty Ltd")
    assert_response :created, response.body
    assert_equal "Acme Coffee Pty Ltd", created.fetch("name")
    assert_equal @newsroom.id, created.fetch("parent_id")
    company_id = created.fetch("id")
    assert_equal company_id, RecordingStudioCompany.companies(@newsroom).sole.id

    shown = call(:get, "/companies/#{company_id}", @editor_token)
    assert_response :success, response.body
    assert_equal "Acme Coffee Pty Ltd", shown.fetch("name")
    assert_equal company_id, RecordingStudioCompany.find(company_id).id

    updated = call(:patch, "/companies/#{company_id}", @editor_token, description: "Roaster")
    assert_response :success, response.body
    assert_equal "Roaster", updated.fetch("description")
    assert_equal "Roaster", RecordingStudioCompany.find(company_id).recordable.description
  end

  test "set_logo and remove_logo are edit capability actions" do
    company = RecordingStudioCompany.create(@newsroom, actor: @owner, name: "Nike, Inc.")
    blob_id = signed_png_id(company)

    set = call(:post, "/companies/#{company.id}/actions/set_logo", @editor_token, signed_blob_id: blob_id)
    assert_response :success, response.body
    assert RecordingStudioCompany.logo(company.reload)

    removed = call(:post, "/companies/#{company.id}/actions/remove_logo", @editor_token)
    assert_response :success, response.body
    assert_nil RecordingStudioCompany.logo(company.reload)
    assert_equal company.id, removed.fetch("id")
  end

  test "unauthenticated calls are 401" do
    get "#{BASE}/companies", params: { parent_id: @newsroom.id }, as: :json
    assert_response :unauthorized
  end

  test "view can read and is forbidden from writes" do
    company = RecordingStudioCompany.create(@newsroom, actor: @owner, name: "Nike, Inc.")

    call(:get, "/companies", @viewer_token, parent_id: @newsroom.id)
    assert_response :success, response.body

    call(:get, "/companies/#{company.id}", @viewer_token)
    assert_response :success, response.body

    call(:post, "/companies", @viewer_token, parent_id: @newsroom.id, name: "Converse")
    assert_response :forbidden, response.body

    call(:patch, "/companies/#{company.id}", @viewer_token, description: "Nope")
    assert_response :forbidden, response.body

    call(:post, "/companies/#{company.id}/actions/set_logo", @viewer_token, signed_blob_id: signed_png_id(company))
    assert_response :forbidden, response.body

    call(:post, "/companies/#{company.id}/actions/remove_logo", @viewer_token)
    assert_response :forbidden, response.body
  end

  test "a company in another workspace is forbidden" do
    stranger_company = RecordingStudioCompany.create(@other, actor: @stranger, name: "Elsewhere")

    call(:get, "/companies/#{stranger_company.id}", @editor_token)
    assert_response :forbidden, response.body

    call(:get, "/companies", @editor_token, parent_id: @other.id)
    assert_response :not_found, response.body
  end

  test "company api registration matches ui roles and skips trash attach helpers" do
    registration = RecordingStudioApi.recordable_registration_for("RecordingStudioCompany::Company")
    assert_equal %i[create index show update], registration.operations
    assert_equal %w[remove_logo set_logo], registration.capability_actions
    assert_equal false, registration.auto_capability_actions

    set_logo = RecordingStudioApi.capability_action(:set_logo)
    remove_logo = RecordingStudioApi.capability_action(:remove_logo)
    assert_equal :edit, set_logo.required_role
    assert_equal :edit, remove_logo.required_role
    assert_equal :attachable, set_logo.capability
    assert_equal RecordingStudioCompany::Api::CompanyResource::Index,
                 RecordingStudioApi.resource_handler("RecordingStudioCompany::Company", :index)
  end

  private

  def user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def owned_root(recordable, actor: @owner)
    root = RecordingStudio.root_recording_for(recordable)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor:)
    raise result.error if result.failure?

    root
  end

  def grant!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(recording:, actor:, role:, manager_actor: @owner)
    raise result.error if result.failure?

    result.value
  end

  def token_for(access_recording)
    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_recording.parent_recording || access_recording.root_recording,
      manager_actor: @owner,
      role: access_recording.recordable.role,
      name: "Client #{SecureRandom.hex(3)}"
    )
    raise provision.error unless provision.success?

    issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise issued.error unless issued.success?

    [issued.value.fetch(:access_token), provision.value.fetch(:api_client)]
  end

  def call(method, path, token, params = {})
    send(method, "#{BASE}#{path}", params:, headers: {
      "Authorization" => "Bearer #{token}",
      "Accept" => "application/json"
    }, as: :json)
    response.media_type.to_s.include?("json") ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end

  def signed_png_id(company)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(png_bytes),
      filename: "logo.png",
      content_type: "image/png",
      identify: false,
      metadata: RecordingStudioAttachable::DirectUpload.metadata_for(recording: company, actor: @editor_client)
    )
    RecordingStudioAttachable::DirectUpload.sign(blob)
  end

  def png_bytes
    row = "\x00".b + ("\x1F\x4E\x79\xFF".b * 2)
    chunk = lambda do |type, data|
      [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
    end
    "\x89PNG\r\n\x1A\n".b +
      chunk.call("IHDR".b, [2, 2, 8, 6, 0, 0, 0].pack("N2C5")) +
      chunk.call("IDAT".b, Zlib::Deflate.deflate(row * 2)) +
      chunk.call("IEND".b, "".b)
  end
end
