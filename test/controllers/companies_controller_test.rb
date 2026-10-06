# frozen_string_literal: true

require_relative "../companies/support"
require "devise/test/integration_helpers"

class CompaniesControllerTest < ActionDispatch::IntegrationTest
  include CompanyTestSupport
  include Devise::Test::IntegrationHelpers

  setup { sign_in owner }

  test "a press centre without a company offers Add" do
    newsroom = press_centre

    get routes.recording_companies_path(newsroom)

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "h1", text: "Company"
    assert_includes page_text, "No company yet"
    assert_select "a[href=?]", routes.new_recording_company_path(newsroom), text: "Add company"
  end

  test "a press centre with a company shows it with view and edit, and no Add" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.", website_url: "https://about.nike.com")

    get routes.recording_companies_path(newsroom)

    assert_response :success
    assert_select "[data-recording-studio-company-card]", count: 1
    assert_select "a[href=?]", routes.company_path(nike), text: "View company"
    assert_select "a[href=?]", routes.edit_company_path(nike), text: "Edit company"
    assert_select "a", text: "Add company", count: 0
  end

  test "new redirects when the press centre already has a company" do
    newsroom = press_centre
    create_company(newsroom, "Nike, Inc.")

    get routes.new_recording_company_path(newsroom)

    assert_redirected_to routes.recording_companies_path(newsroom)
    assert_equal "A company can't be added here.", flash[:alert]
  end

  test "a trashed company offers Restore and no Add" do
    newsroom = press_centre
    nike = trash(create_company(newsroom, "Nike, Inc."))

    get routes.recording_companies_path(newsroom)

    assert_response :success
    assert_includes page_text, "Nike, Inc. is in the trash"
    assert_select "form[action=?][method=post] button[type=submit]", routes.restore_company_path(nike),
                  text: "Restore company"
    assert_select "a", text: "Add company", count: 0
  end

  test "a press centre with two companies states the integrity error and offers no Add" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.")
    adidas = record_unchecked_company(newsroom, "Adidas AG")

    get routes.recording_companies_path(newsroom)

    assert_response :success
    assert_includes page_text, "Nike Newsroom has 2 companies"
    assert_includes page_text, "This press centre holds one company."
    assert_select "a[href=?]", routes.company_path(nike), text: "View"
    assert_select "a[href=?]", routes.company_path(adidas), text: "View"
    assert_select "a", text: "Add company", count: 0
  end

  test "posting a company to a press centre with two companies redirects with the integrity error" do
    newsroom = press_centre
    create_company(newsroom, "Nike, Inc.")
    record_unchecked_company(newsroom, "Adidas AG")

    assert_no_difference -> { company_children(newsroom).count } do
      post routes.recording_companies_path(newsroom), params: { company: { name: "Puma SE" } }
    end

    assert_redirected_to routes.recording_companies_path(newsroom)
    assert_equal "Only one company is allowed here, but 2 companies are recorded", flash[:alert]
  end

  test "an agency lists its companies with Add, view, and edit, and its trashed companies with Restore" do
    northwind = agency
    unilever = create_company(northwind, "Unilever", legal_name: "Unilever PLC", website_url: "https://www.unilever.com")
    nike = create_company(northwind, "Nike, Inc.")
    acme = trash(create_company(northwind, "Acme Coffee Pty Ltd"))

    get routes.recording_companies_path(northwind)

    assert_response :success
    assert_select "h1", text: "Companies"
    assert_select "a[href=?]", routes.new_recording_company_path(northwind), text: "Add company"
    assert_select "table tbody tr", count: 2
    assert_select "a[href=?]", routes.company_path(nike), text: "View"
    assert_select "a[href=?]", routes.edit_company_path(unilever), text: "Edit"
    assert_includes page_text, "Unilever PLC"
    assert_includes page_text, "www.unilever.com"
    assert_includes page_text, "In trash"
    assert_select "form[action=?] button[aria-label=?]", routes.restore_company_path(acme),
                  "Restore Acme Coffee Pty Ltd", text: "Restore"
  end

  test "an agency without companies says so and still offers Add" do
    northwind = agency

    get routes.recording_companies_path(northwind)

    assert_response :success
    assert_includes page_text, "No companies yet"
    assert_select "a[href=?]", routes.new_recording_company_path(northwind), text: "Add company"
  end

  test "the form has an input for every field, with the model's length limits" do
    northwind = agency

    get routes.new_recording_company_path(northwind)

    assert_response :success
    RecordingStudioCompany::Company::FIELDS.each do |field|
      assert_select "[name=?]", "company[#{field}]", count: 1
    end
    RecordingStudioCompany::Company::LIMITS.each do |field, maximum|
      assert_select "[name=?][maxlength=?]", "company[#{field}]", maximum.to_s
    end
    assert_select "input[name='company[name]'][required]"
    assert_select "input[name='company[founded_on]'][type=date]"
    assert_select "input[type=hidden][name=idempotency_key]", count: 1
  end

  test "adding a company through the form" do
    northwind = agency
    get routes.new_recording_company_path(northwind)
    key = css_select("input[name=idempotency_key]").first["value"]

    assert_difference -> { company_children(northwind).count }, 1 do
      post routes.recording_companies_path(northwind), params: {
        idempotency_key: key,
        company: { name: "Unilever", legal_name: "Unilever PLC", founded_on: "1929-09-02" }
      }
    end

    unilever = company_children(northwind).sole
    assert_response :see_other
    assert_redirected_to routes.company_path(unilever)
    assert_equal Date.new(1929, 9, 2), unilever.recordable.founded_on

    follow_redirect!

    assert_includes page_text, "Unilever was added."
    assert_select "h1", text: "Unilever"
  end

  test "a double submit with the same idempotency key adds one company" do
    northwind = agency
    params = { idempotency_key: "form-key-1", company: { name: "Unilever" } }

    assert_difference -> { company_children(northwind).count }, 1 do
      2.times { post routes.recording_companies_path(northwind), params: }
    end

    assert_redirected_to routes.company_path(company_children(northwind).sole)
  end

  test "an invalid company re-renders the form with its errors and values" do
    northwind = agency

    assert_no_difference -> { company_children(northwind).count } do
      post routes.recording_companies_path(northwind), params: {
        idempotency_key: "form-key-2",
        company: { name: " ", website_url: "about.nike.com", founded_on: "soon" }
      }
    end

    assert_response :unprocessable_content
    assert_includes page_text, "The company could not be saved"
    assert_includes page_text, "Name can't be blank"
    assert_includes page_text, "Founded on is invalid"
    assert_select "input[name=idempotency_key][value=?]", "form-key-2"
    assert_select "input[name='company[website_url]'][value=?]", "about.nike.com"
  end

  test "editing a company keeps its recording and changes its fields" do
    nike = create_company(press_centre, "Nike")

    get routes.edit_company_path(nike)

    assert_response :success
    assert_select "input[name='company[name]'][value=?]", "Nike"
    assert_select "button", text: "Upload logo"
    assert_select "input[name=idempotency_key]", count: 0

    patch routes.company_path(nike), params: { company: { name: "Nike, Inc.", founded_on: "1964-01-25" } }

    assert_response :see_other
    assert_redirected_to routes.company_path(nike)
    assert_equal "Nike, Inc.", nike.reload.recordable.name
    assert_equal Date.new(1964, 1, 25), nike.recordable.founded_on
  end

  test "an invalid edit re-renders the form with its errors" do
    nike = create_company(press_centre, "Nike, Inc.")

    patch routes.company_path(nike), params: { company: { name: "", phone: "1" * 51 } }

    assert_response :unprocessable_content
    assert_includes page_text, "Name can't be blank"
    assert_includes page_text, "Phone is too long (maximum is 50 characters)"
    assert_equal "Nike, Inc.", nike.reload.recordable.name
  end

  test "moving a company to the trash and restoring it" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.")

    get routes.company_path(nike)

    assert_select "form[action=?] input[name=_method][value=delete]", routes.company_path(nike)
    assert_select "button", text: "Move to trash"

    delete routes.company_path(nike)

    assert_redirected_to routes.recording_companies_path(newsroom)
    assert nike.reload.trashed_at
    follow_redirect!
    assert_includes page_text, "Nike, Inc. is in the trash."

    get routes.company_path(nike)

    assert_includes page_text, "Restore it to change it again."
    assert_select "button", text: "Move to trash", count: 0
    assert_select "a", text: "Edit company", count: 0

    post routes.restore_company_path(nike)

    assert_redirected_to routes.company_path(nike)
    assert_nil nike.reload.trashed_at
    follow_redirect!
    assert_includes page_text, "Nike, Inc. was restored."
  end

  test "a trashed company is restored before it can be edited" do
    nike = trash(create_company(press_centre, "Nike, Inc."))

    get routes.edit_company_path(nike)

    assert_redirected_to routes.company_path(nike)
    assert_equal "Restore Nike, Inc. before changing it", flash[:alert]

    patch routes.company_path(nike), params: { company: { name: "Nike" } }

    assert_redirected_to routes.company_path(nike)
    assert_equal "Nike, Inc.", nike.reload.recordable.name
  end

  test "a viewer sees the company without write buttons and cannot change it" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.")
    sign_in grant(newsroom, create_user("viewer"), "view")

    get routes.recording_companies_path(newsroom)

    assert_response :success
    assert_select "a", text: "View company"
    assert_select "a", text: "Edit company", count: 0

    get routes.company_path(nike)

    assert_response :success
    assert_select "button", text: "Move to trash", count: 0

    get routes.edit_company_path(nike)

    assert_redirected_to routes.company_path(nike)

    patch routes.company_path(nike), params: { company: { name: "Nike" } }

    assert_response :forbidden
    assert_includes page_text, "You don't have permission to make this change."

    delete routes.company_path(nike)

    assert_response :forbidden
    assert_nil nike.reload.trashed_at
  end

  test "a viewer cannot add a company" do
    northwind = agency
    sign_in grant(northwind, create_user("viewer"), "view")

    get routes.recording_companies_path(northwind)

    assert_select "a", text: "Add company", count: 0

    get routes.new_recording_company_path(northwind)

    assert_redirected_to routes.recording_companies_path(northwind)

    assert_no_difference -> { company_children(northwind).count } do
      post routes.recording_companies_path(northwind), params: { company: { name: "Unilever" } }
    end
    assert_response :forbidden
  end

  test "parents that are unknown, hold no companies, or cannot be viewed are not found" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.")

    get routes.recording_companies_path(SecureRandom.uuid)

    assert_response :not_found
    assert_includes page_text, "This page doesn't exist, or you can't see it."

    get routes.recording_companies_path(workspace)

    assert_response :not_found

    get routes.company_path(SecureRandom.uuid)

    assert_response :not_found

    sign_in create_user("stranger")

    get routes.recording_companies_path(newsroom)

    assert_response :not_found

    get routes.company_path(nike)

    assert_response :not_found
  end

  test "uploading, replacing, and removing the logo" do
    nike = create_company(press_centre, "Nike, Inc.")

    patch routes.logo_company_path(nike), params: { logo: { signed_blob_id: png_blob.signed_id } }

    assert_redirected_to routes.edit_company_path(nike)
    assert_equal "The logo was updated.", flash[:notice]
    logo = RecordingStudioCompany.logo(nike)
    assert logo

    get routes.edit_company_path(nike)

    assert_select "img[alt=?]", "Nike, Inc. logo"
    assert_select "button", text: "Change logo"
    assert_select "form[action=?] input[name=_method][value=delete]", routes.logo_company_path(nike)

    patch routes.logo_company_path(nike), params: { logo: { signed_blob_id: png_blob("logo-2.png").signed_id } }

    assert_equal logo.id, RecordingStudioCompany.logo(nike).id
    assert_equal "logo-2.png", RecordingStudioCompany.logo(nike).recordable.file.filename.to_s

    delete routes.logo_company_path(nike)

    assert_redirected_to routes.edit_company_path(nike)
    assert_equal "The logo was removed.", flash[:notice]
    assert_nil RecordingStudioCompany.logo(nike)
    assert_equal 1, logo_children(nike).count
  end

  test "a rejected logo shows an alert and adds nothing" do
    nike = create_company(press_centre, "Nike, Inc.")

    assert_no_difference -> { logo_children(nike).count } do
      patch routes.logo_company_path(nike), params: { logo: { signed_blob_id: text_blob.signed_id } }
    end

    assert_redirected_to routes.edit_company_path(nike)
    assert_predicate flash[:alert], :present?
  end

  test "submitting the logo form without a file asks for an image" do
    nike = create_company(press_centre, "Nike, Inc.")

    [{ logo: { signed_blob_id: "" } }, { logo: "logo.png" }].each do |params|
      patch(routes.logo_company_path(nike), params:)

      assert_redirected_to routes.edit_company_path(nike)
      assert_equal "Choose an image to upload.", flash[:alert]
    end
    assert_empty logo_children(nike)
  end

  test "company fields that are not a hash are a bad request" do
    northwind = agency

    assert_no_difference -> { company_children(northwind).count } do
      post routes.recording_companies_path(northwind), params: { company: "Unilever" }
    end

    assert_response :bad_request
  end

  test "the logo form uploads through Attachable's controller with the company's limits" do
    nike = create_company(press_centre, "Nike, Inc.")
    prefix = "data-recording-studio-attachable--attachment-revision-upload"

    get routes.edit_company_path(nike)

    form = css_select("form[data-controller='recording-studio-attachable--attachment-revision-upload']").sole
    assert_equal routes.logo_company_path(nike), form["action"]
    assert_equal "/rails/active_storage/direct_uploads", form["#{prefix}-direct-upload-url-value"]
    assert_equal "logo[signed_blob_id]", form["#{prefix}-signed-blob-field-name-value"]
    assert_equal "true", form["#{prefix}-auto-submit-value"]
    assert_equal 10.megabytes.to_s, form["#{prefix}-max-file-size-value"]
    assert_select form, "input[type=file][accept=?]", "image/*"
    assert_select form, "input[type=hidden][name=?]", "logo[signed_blob_id]"
  end

  test "page copy says company, never recording or recordable" do
    newsroom = press_centre
    northwind = agency
    nike = create_company(newsroom, "Nike, Inc.")
    trashed = trash(create_company(northwind, "Acme Coffee Pty Ltd"))
    paths = [
      routes.recording_companies_path(newsroom),
      routes.recording_companies_path(northwind),
      routes.new_recording_company_path(northwind),
      routes.company_path(nike),
      routes.edit_company_path(nike),
      routes.company_path(trashed),
      routes.recording_companies_path(SecureRandom.uuid)
    ]

    paths.each do |path|
      get path

      assert_no_match(/record(ing|able)/i, css_select("main").text, "#{path} mentions recordings")
    end
  end

  private

  def routes
    recording_studio_company
  end

  def page_text
    css_select("main").text.squish
  end
end
