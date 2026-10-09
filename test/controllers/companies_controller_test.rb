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
    assert_select "h1", text: "Companies and organisations"
    assert_includes page_text, "No company yet"
    refute_includes page_text, "Nike Newsroom"
    assert_select "a[href=?]", routes.new_recording_company_path(newsroom), text: "+ Company"
  end

  test "a press centre with a company shows it with view and edit, and no Add" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.", website_url: "https://about.nike.com")

    get routes.recording_companies_path(newsroom)

    assert_response :success
    assert_select "h1", text: "Companies and organisations"
    assert_select "[data-recording-studio-company-card]", count: 0
    assert_select "a[href=?]", routes.company_path(nike), text: "Nike, Inc."
    assert_select "[class*=?]", "md:grid-cols-2"
    refute_includes page_text, "Nike Newsroom"
    assert_select "a", text: "+ Company", count: 0
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
    assert_select "a", text: "+ Company", count: 0
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
    assert_select "a", text: "+ Company", count: 0
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
    unilever = create_company(northwind, "Unilever", description: "Consumer goods", website_url: "https://www.unilever.com")
    nike = create_company(northwind, "Nike, Inc.")
    acme = trash(create_company(northwind, "Acme Coffee Pty Ltd"))

    get routes.recording_companies_path(northwind)

    assert_response :success
    assert_select "h1", text: "Companies and organisations"
    refute_includes page_text, "Northwind"
    assert_select "a[href=?]", routes.new_recording_company_path(northwind), text: "+ Company"
    assert_select "table", count: 0
    assert_select "a[href=?]", routes.company_path(nike), text: "Nike, Inc."
    assert_select "a[href=?]", routes.company_path(unilever), text: "Unilever"
    assert_select "[class*=?]", "md:grid-cols-2"
    assert_select "a.flat-pack-list-item-link[class*=?]", "items-center"
    assert_select "a.flat-pack-list-item-link[class*=?]", "items-start", count: 0
    refute_includes page_text, "Consumer goods"
    refute_includes page_text, "www.unilever.com"
    assert_includes page_text, "In trash"
    assert_select "form[action=?] button[aria-label=?]", routes.restore_company_path(acme),
                  "Restore Acme Coffee Pty Ltd", text: "Restore"
  end

  test "an agency without companies says so and still offers Add" do
    northwind = agency

    get routes.recording_companies_path(northwind)

    assert_response :success
    assert_includes page_text, "No companies yet"
    assert_select "a[href=?]", routes.new_recording_company_path(northwind), text: "+ Company"
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
    assert_select "input[name='company[founded_on]']", count: 0
    assert_select "input[name='company[legal_name]']", count: 0
    assert_select "input[name='company[email]']", count: 0
    assert_select "input[name='company[phone]']", count: 0
    body = response.body
    assert_operator body.index("company[name]"), :<, body.index("company[website_url]")
    assert_operator body.index("company[website_url]"), :<, body.index("company[description]")
    assert_select "button", text: "Delete", count: 0
    assert_select "button[type=submit][data-fp-style=?]", "primary", text: "Add company"
    assert_select "form[data-controller=?]", "flat-pack--unsaved-changes", count: 0
    assert_select "input[type=hidden][name=idempotency_key]", count: 1
  end

  test "Save stays the default style until the edit form changes, and Delete sits on that row" do
    nike = create_company(press_centre, "Nike")

    get routes.edit_company_path(nike)

    assert_select "[role=separator]", count: 0
    assert_select "div.flex.flex-wrap.items-center.gap-3" do
      assert_select "button[type=submit][data-fp-style=?][data-flat-pack--unsaved-changes-target=?]",
                    "default", "submit", text: "Save"
      assert_select "button.ml-auto[form=delete-company][data-fp-style=?]", "danger", text: "Delete"
    end
    assert_select "form#delete-company[action=?] input[name=_method][value=delete]", routes.company_path(nike)
    assert_select "button", text: "Update", count: 0
    assert_select "button", text: "Save company", count: 0
  end

  test "adding a company through the form" do
    northwind = agency
    get routes.new_recording_company_path(northwind)
    key = css_select("input[name=idempotency_key]").first["value"]

    assert_difference -> { company_children(northwind).count }, 1 do
      post routes.recording_companies_path(northwind), params: {
        idempotency_key: key,
        company: { name: "Unilever", website_url: "https://www.unilever.com", description: "Consumer goods" }
      }
    end

    unilever = company_children(northwind).sole
    assert_response :see_other
    assert_redirected_to routes.company_path(unilever)
    assert_equal "https://www.unilever.com", unilever.recordable.website_url
    assert_equal "Consumer goods", unilever.recordable.description

    follow_redirect!

    assert_includes page_text, "Unilever was added."
    assert_select "h1", text: "Unilever"
  end

  test "the company page stacks the logo, name, description, and website, with edit at the bottom" do
    nike = create_company(
      press_centre, "Nike, Inc.",
      description: "Athletic footwear and apparel.",
      website_url: "https://about.nike.com/"
    )
    RecordingStudioCompany.set_logo(nike, signed_blob_id: png_blob.signed_id, actor: owner)
    get routes.company_path(nike)

    assert_response :success
    assert_select "h1", text: "Nike, Inc."
    assert_select "[data-recording-studio-company-card], .page-title-actions", count: 0
    assert_select "img[alt=?]", "Nike, Inc. logo"
    assert_select "[class*=?]", "avatar-radius-circle"
    assert_select "p.whitespace-pre-line", text: "Athletic footwear and apparel."
    assert_select "svg[data-flat-pack--icon-name-value=?]", "globe-alt"
    assert_select "a[href=?][target=_blank][rel=?]", "https://about.nike.com/", "noopener noreferrer",
                  text: "about.nike.com"
    refute_includes page_text, "Nike Newsroom"
    refute_includes page_text, "Website"
    markers = ["Nike, Inc. logo", "<h1", "Athletic footwear and apparel.", "about.nike.com", "Edit company"]
    indexes = markers.map { |marker| response.body.index(marker) }
    assert_equal markers.size, indexes.compact.size
    assert_equal indexes, indexes.sort
  end

  test "the company page shows a bare website as typed and leaves blank fields out" do
    acme = create_company(agency, "Acme Coffee Pty Ltd", website_url: "acmecoffee.example")

    get routes.company_path(acme)

    assert_select "h1", text: "Acme Coffee Pty Ltd"
    assert_select "p.whitespace-pre-line", count: 0
    assert_select "a[href=?][target=_blank]", "https://acmecoffee.example", text: "acmecoffee.example"
    assert_select "a[href=?]", routes.edit_company_path(acme), text: "Edit company"
    refute_includes page_text, "Website"
  end

  test "the company page shows an unsafe website as text" do
    company = create_company(agency, "Odd Website Pty Ltd", website_url: "javascript:alert(1)")

    get routes.company_path(company)

    assert_includes page_text, "javascript:alert(1)"
    assert_select "a[href^='javascript']", count: 0
    assert_select "a[target=_blank]", count: 0
    assert_select "svg[data-flat-pack--icon-name-value=?]", "globe-alt"
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
        company: { name: " ", website_url: "about.nike.com", description: "d" * 5_001 }
      }
    end

    assert_response :unprocessable_content
    assert_includes page_text, "The company could not be saved"
    assert_includes page_text, "Name can't be blank"
    assert_includes page_text, "Description is too long (maximum is 5000 characters)"
    refute_includes page_text, "Phone"
    assert_select "input[name=idempotency_key][value=?]", "form-key-2"
    assert_select "input[name='company[website_url]'][value=?]", "about.nike.com"
  end

  test "editing a company keeps its recording and changes its fields" do
    nike = create_company(press_centre, "Nike")

    get routes.edit_company_path(nike)

    assert_response :success
    assert_select "input[name='company[name]'][value=?]", "Nike"
    assert_select "button", text: "Upload logo"
    assert_select "h2", text: "Logo", count: 0
    assert_select "p", text: "One image for the company.", count: 0
    assert_select "input[name=idempotency_key]", count: 0
    assert_select "[role=separator]", count: 0
    assert_select "button.ml-auto[data-fp-style=?]", "danger", text: "Delete"

    patch routes.company_path(nike), params: { company: { name: "Nike, Inc.", website_url: "https://about.nike.com" } }

    assert_response :see_other
    assert_redirected_to routes.company_path(nike)
    assert_equal "Nike, Inc.", nike.reload.recordable.name
    assert_equal "https://about.nike.com", nike.recordable.website_url
  end

  test "an invalid edit re-renders the form with its errors" do
    nike = create_company(press_centre, "Nike, Inc.")

    patch routes.company_path(nike), params: { company: { name: "", description: "d" * 5_001 } }

    assert_response :unprocessable_content
    assert_includes page_text, "Name can't be blank"
    assert_includes page_text, "Description is too long (maximum is 5000 characters)"
    assert_equal "Nike, Inc.", nike.reload.recordable.name
  end

  test "moving a company to the trash and restoring it" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.")

    get routes.company_path(nike)

    assert_select "button", text: "Move to trash", count: 0
    assert_select "button", text: "Delete", count: 0

    get routes.edit_company_path(nike)

    assert_select "[role=separator]", count: 0
    assert_select "form#delete-company[action=?] input[name=_method][value=delete]", routes.company_path(nike)
    assert_select "button.ml-auto[data-fp-style=?]", "danger", text: "Delete"

    delete routes.company_path(nike)

    assert_redirected_to routes.recording_companies_path(newsroom)
    assert nike.reload.trashed_at
    follow_redirect!
    assert_includes page_text, "Nike, Inc. is in the trash."

    get routes.company_path(nike)

    assert_includes page_text, "Restore it to change it again."
    assert_select "button", text: "Move to trash", count: 0
    assert_select "button", text: "Delete", count: 0
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
    assert_select "a[href=?]", routes.company_path(nike), text: "Nike, Inc."
    assert_select "a", text: "Edit company", count: 0

    get routes.company_path(nike)

    assert_response :success
    assert_select "button", text: "Move to trash", count: 0
    assert_select "button", text: "Delete", count: 0
    assert_select "a", text: "Edit company", count: 0

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

    assert_select "a", text: "+ Company", count: 0

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
    assert_select "h2", text: "Logo", count: 0
    assert_select "p", text: "One image for the company.", count: 0
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
