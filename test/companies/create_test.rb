# frozen_string_literal: true

require_relative "support"

class CompanyCreateTest < ActiveSupport::TestCase
  include CompanyTestSupport

  test "a press centre records its company under itself" do
    newsroom = press_centre

    nike = create_company(
      newsroom,
      "Nike, Inc.",
      website_url: "https://about.nike.com",
      description: "Athletic footwear."
    )

    assert_equal newsroom, nike.parent_recording
    assert_equal newsroom, nike.root_recording
    assert_equal "Nike, Inc.", nike.recordable.name
    assert_equal "https://about.nike.com", nike.recordable.website_url
    assert_equal "Athletic footwear.", nike.recordable.description
    assert_equal ["created"], nike.events.map(&:action)
    assert_equal owner, nike.events.first.actor
  end

  test "a press centre rejects a second company and names the first" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.")

    error = assert_raises(RecordingStudioCompany::CompanyAlreadyExists) { create_company(newsroom, "Adidas AG") }

    assert_equal nike, error.company
    assert_equal "Nike, Inc. is already the company here", error.message
    assert_equal [nike.id], company_children(newsroom).pluck(:id)
    assert_equal 0, RecordingStudioCompany::Company.where(name: "Adidas AG").count
  end

  test "a press centre rejects a second company recorded directly with record!" do
    newsroom = press_centre
    create_company(newsroom, "Nike, Inc.")

    assert_no_difference -> { RecordingStudioCompany::Company.count } do
      assert_no_difference -> { RecordingStudio::Event.count } do
        error = assert_raises(ActiveRecord::RecordInvalid) do
          RecordingStudio.record!(
            action: "created",
            recordable: RecordingStudioCompany::Company.new(name: "Adidas AG"),
            root_recording: newsroom,
            parent_recording: newsroom,
            actor: owner
          )
        end

        assert_equal "Validation failed: Only one company is allowed here", error.message
        assert error.record.errors.of_kind?(:base, :company_taken)
      end
    end
    assert_equal 1, company_children(newsroom).count
  end

  test "a press centre rejects a second company recorded through Recording#record and create!" do
    newsroom = press_centre
    create_company(newsroom, "Nike, Inc.")

    assert_raises(ActiveRecord::RecordInvalid) do
      newsroom.record(RecordingStudioCompany::Company.new(name: "Adidas AG"), actor: owner)
    end
    assert_raises(ActiveRecord::RecordInvalid) do
      RecordingStudio::Recording.create!(
        root_recording: newsroom,
        parent_recording: newsroom,
        recordable: RecordingStudioCompany::Company.create!(name: "Puma SE")
      )
    end
    assert_equal ["Nike, Inc."], names(company_children(newsroom))
  end

  test "an agency accepts three companies" do
    northwind = agency

    names = ["Nike, Inc.", "Unilever", "Acme Coffee Pty Ltd"].map do |name|
      create_company(northwind, name).recordable.name
    end

    assert_equal ["Nike, Inc.", "Unilever", "Acme Coffee Pty Ltd"], names
    assert_equal 3, company_children(northwind).count
  end

  test "a project under an agency allows one company" do
    northwind = agency
    fit_out = project(northwind)

    acme = create_company(fit_out, "Acme Engineering Pty Ltd")
    error = assert_raises(RecordingStudioCompany::CompanyAlreadyExists) { create_company(fit_out, "Acme Coffee") }

    assert_equal acme, error.company
    assert_equal fit_out, acme.parent_recording
    assert_equal northwind, acme.root_recording
  end

  test "moving a company into a project that holds one is invalid" do
    northwind = agency
    fit_out = project(northwind)
    create_company(fit_out, "Acme Engineering Pty Ltd")
    unilever = create_company(northwind, "Unilever")

    unilever.parent_recording = fit_out

    assert_not unilever.save
    assert_equal ["Only one company is allowed here"], unilever.errors[:base]
    assert_equal northwind.id, unilever.reload.parent_recording_id
  end

  test "a trashed company still holds the press centre's place until it is purged" do
    newsroom = press_centre
    nike = trash(create_company(newsroom, "Nike, Inc."))

    error = assert_raises(RecordingStudioCompany::CompanyAlreadyExists) { create_company(newsroom, "Adidas AG") }
    assert_equal nike, error.company
    assert_predicate error.company.trashed_at, :present?

    nike.recording_studio_trashable_purge!(actor: owner)
    adidas = create_company(newsroom, "Adidas AG")

    assert_equal [adidas.id], company_children(newsroom).pluck(:id)
  end

  test "restoring a trashed company leaves one live company" do
    newsroom = press_centre
    nike = restore(trash(create_company(newsroom, "Nike, Inc.")))

    assert_nil nike.trashed_at
    assert_equal nike, RecordingStudioCompany.company(newsroom)
    assert_equal 1, company_children(newsroom).count
  end

  test "a host default scope that hides trashed recordings does not free the place" do
    newsroom = press_centre
    trash(create_company(newsroom, "Nike, Inc."))
    scopes = RecordingStudio::Recording.default_scopes
    RecordingStudio::Recording.class_eval { default_scope { where(trashed_at: nil) } }

    assert_raises(RecordingStudioCompany::CompanyAlreadyExists) { create_company(newsroom, "Adidas AG") }
  ensure
    RecordingStudio::Recording.default_scopes = scopes
  end

  test "the same idempotency key returns the first company under either allowance" do
    newsroom = press_centre
    northwind = agency

    [newsroom, northwind].each do |parent|
      first = RecordingStudioCompany.create(parent, actor: owner, idempotency_key: "form-1", name: "Nike, Inc.")
      again = RecordingStudioCompany.create(parent, actor: owner, idempotency_key: "form-1", name: "Nike, Inc.")

      assert_equal first, again
      assert_equal 1, company_children(parent).count
      assert_equal 1, first.events.count
    end
  end

  test "an idempotency key returns its company after it was trashed" do
    newsroom = press_centre
    nike = trash(RecordingStudioCompany.create(newsroom, actor: owner, idempotency_key: "form-1", name: "Nike, Inc."))

    again = RecordingStudioCompany.create(newsroom, actor: owner, idempotency_key: "form-1", name: "Nike, Inc.")

    assert_equal nike, again
  end

  test "a different idempotency key creates a second company only where many are allowed" do
    newsroom = press_centre
    northwind = agency
    RecordingStudioCompany.create(newsroom, actor: owner, idempotency_key: "form-1", name: "Nike, Inc.")
    RecordingStudioCompany.create(northwind, actor: owner, idempotency_key: "form-1", name: "Nike, Inc.")

    assert_raises(RecordingStudioCompany::CompanyAlreadyExists) do
      RecordingStudioCompany.create(newsroom, actor: owner, idempotency_key: "form-2", name: "Nike, Inc.")
    end
    RecordingStudioCompany.create(northwind, actor: owner, idempotency_key: "form-2", name: "Unilever")

    assert_equal 2, company_children(northwind).count
  end

  test "name is required" do
    newsroom = press_centre

    error = assert_raises(RecordingStudioCompany::Invalid) { create_company(newsroom, "  ") }

    assert_equal "Name can't be blank", error.message
    assert_equal ["can't be blank"], error.record.errors[:name]
    assert_equal 0, company_children(newsroom).count
  end

  test "blank optional fields are stored as unknown" do
    nike = create_company(press_centre, "Nike, Inc.", description: " ", website_url: "")

    assert_nil nike.recordable.description
    assert_nil nike.recordable.website_url
  end

  test "website is stored as typed" do
    nike = create_company(press_centre, "Nike, Inc.", website_url: "nike.com")

    assert_equal "nike.com", nike.recordable.website_url
  end

  test "retired fields are rejected before anything is written" do
    newsroom = press_centre

    error = assert_raises(ArgumentError) do
      create_company(
        newsroom,
        "Nike, Inc.",
        legal_name: "Nike, Inc.",
        email: "press@nike.example",
        phone: "+1 503 671 6453",
        founded_on: "1964-01-25"
      )
    end

    assert_equal "Unknown company field(s): legal_name, email, phone, founded_on", error.message
    assert_equal 0, company_children(newsroom).count
  end

  test "unknown fields are rejected before anything is written" do
    newsroom = press_centre

    error = assert_raises(ArgumentError) { create_company(newsroom, "Nike, Inc.", slogan: "Just do it") }

    assert_equal "Unknown company field(s): slogan", error.message
    assert_equal 0, company_children(newsroom).count
  end

  test "creating needs edit access on the parent" do
    newsroom = press_centre
    viewer = grant(newsroom, create_user("viewer"), "view")
    stranger = create_user("stranger")

    [viewer, stranger, nil].each do |actor|
      error = assert_raises(RecordingStudioCompany::NotAuthorized) do
        RecordingStudioCompany.create(newsroom, actor:, name: "Nike, Inc.")
      end
      assert_equal "Changing this press centre needs edit access", error.message
    end
    assert_equal 0, company_children(newsroom).count
  end

  test "edit access on the agency is enough to create under its project" do
    northwind = agency
    fit_out = project(northwind)
    editor = grant(northwind, create_user("editor"), "edit")

    acme = RecordingStudioCompany.create(fit_out, actor: editor, name: "Acme Engineering Pty Ltd")

    assert_equal fit_out, acme.parent_recording
  end

  test "a host authorize_write that denies the write is reported as not authorized" do
    newsroom = press_centre
    host_rule = ->(**) { false }
    RecordingStudio.configuration.authorize_write = host_rule

    error = assert_raises(RecordingStudioCompany::NotAuthorized) { create_company(newsroom, "Nike, Inc.") }

    assert_equal "RecordingStudio write was denied by config.authorize_write", error.message
    assert_same host_rule, RecordingStudio.configuration.authorize_write
    assert_equal 0, company_children(newsroom).count
  ensure
    RecordingStudio.configuration.authorize_write = nil
  end

  test "parents whose type does not hold companies are rejected" do
    studio = workspace
    folder = studio.record(Folder.new(name: "Product Docs"), actor: owner)

    error = assert_raises(RecordingStudioCompany::ParentNotAllowed) { create_company(folder, "Nike, Inc.") }

    assert_equal "Folder does not hold companies", error.message
  end
end
