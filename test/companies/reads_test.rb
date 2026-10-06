# frozen_string_literal: true

require_relative "support"

class CompanyReadsTest < ActiveSupport::TestCase
  include CompanyTestSupport

  test "company returns nothing, then the press centre's company" do
    newsroom = press_centre

    assert_nil RecordingStudioCompany.company(newsroom)

    nike = create_company(newsroom, "Nike, Inc.")

    assert_equal nike, RecordingStudioCompany.company(newsroom)
  end

  test "a trashed company is returned only when asked for" do
    newsroom = press_centre
    nike = trash(create_company(newsroom, "Nike, Inc."))

    assert_nil RecordingStudioCompany.company(newsroom)
    assert_equal nike, RecordingStudioCompany.company(newsroom, include_trashed: true)
  end

  test "company on an agency raises because an agency allows many" do
    northwind = agency
    create_company(northwind, "Nike, Inc.")

    error = assert_raises(RecordingStudioCompany::ManyCompaniesAllowed) { RecordingStudioCompany.company(northwind) }

    assert_equal "Agency allows many companies; use companies(parent)", error.message
  end

  test "company on a workspace raises because workspaces hold no companies" do
    error = assert_raises(RecordingStudioCompany::ParentNotAllowed) { RecordingStudioCompany.company(workspace) }

    assert_equal "Workspace does not hold companies", error.message
  end

  test "a press centre holding two company recordings raises instead of picking one" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.")
    adidas = record_unchecked_company(newsroom, "Adidas AG")

    error = assert_raises(RecordingStudioCompany::CompanyIntegrityError) { RecordingStudioCompany.company(newsroom) }

    assert_equal [nike, adidas], error.companies
    assert_equal "Only one company is allowed here, but 2 companies are recorded", error.message
  end

  test "a trashed extra company still counts toward the integrity error" do
    newsroom = press_centre
    create_company(newsroom, "Nike, Inc.")
    trash(record_unchecked_company(newsroom, "Adidas AG"))

    assert_raises(RecordingStudioCompany::CompanyIntegrityError) do
      RecordingStudioCompany.company(newsroom, include_trashed: true)
    end
    assert_raises(RecordingStudioCompany::CompanyIntegrityError) { RecordingStudioCompany.company(newsroom) }
  end

  test "creating under a press centre with two company recordings raises the integrity error" do
    newsroom = press_centre
    create_company(newsroom, "Nike, Inc.")
    record_unchecked_company(newsroom, "Adidas AG")

    assert_raises(RecordingStudioCompany::CompanyIntegrityError) { create_company(newsroom, "Puma SE") }
    assert_equal false, RecordingStudioCompany.can?(:create, newsroom, actor: owner)
  end

  test "companies lists by name ignoring case, then by creation" do
    northwind = agency
    create_company(northwind, "Unilever")
    first_acme = create_company(northwind, "acme Coffee Pty Ltd")
    second_acme = create_company(northwind, "Acme Coffee Pty Ltd")
    create_company(northwind, "Nike, Inc.")

    listed = RecordingStudioCompany.companies(northwind)

    assert_equal ["acme Coffee Pty Ltd", "Acme Coffee Pty Ltd", "Nike, Inc.", "Unilever"], names(listed)
    assert_equal [first_acme, second_acme], listed.first(2)
  end

  test "companies leaves out trashed companies unless asked" do
    northwind = agency
    create_company(northwind, "Nike, Inc.")
    trash(create_company(northwind, "Unilever"))

    assert_equal ["Nike, Inc."], names(RecordingStudioCompany.companies(northwind))
    assert_equal ["Nike, Inc.", "Unilever"], names(RecordingStudioCompany.companies(northwind, include_trashed: true))
  end

  test "companies lists the single company of a press centre" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.")

    assert_equal [nike], RecordingStudioCompany.companies(newsroom)
    assert_raises(RecordingStudioCompany::ParentNotAllowed) { RecordingStudioCompany.companies(workspace) }
  end

  test "find resolves a stored company recording id" do
    nike = create_company(press_centre, "Nike, Inc.")

    assert_equal nike, RecordingStudioCompany.find(nike.id)
  end

  test "find raises not found for ids that are not live companies" do
    newsroom = press_centre
    trashed = trash(create_company(newsroom, "Nike, Inc."))

    [SecureRandom.uuid, "not-a-uuid", nil, newsroom.id, trashed.id].each do |id|
      error = assert_raises(RecordingStudioCompany::NotFound) { RecordingStudioCompany.find(id) }
      assert_equal "No company #{id.inspect}", error.message
    end
    assert_equal trashed, RecordingStudioCompany.find(trashed.id, include_trashed: true)
  end

  test "reads do not check access" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.")

    assert_equal nike, RecordingStudioCompany.company(newsroom)
    assert_equal [nike], RecordingStudioCompany.companies(newsroom)
    assert_equal nike, RecordingStudioCompany.find(nike.id)
  end

  test "can create follows the press centre's free place and edit access" do
    newsroom = press_centre
    viewer = grant(newsroom, create_user("viewer"), "view")

    assert RecordingStudioCompany.can?(:create, newsroom, actor: owner)
    refute RecordingStudioCompany.can?(:create, newsroom, actor: viewer)
    refute RecordingStudioCompany.can?(:create, newsroom, actor: nil)

    nike = create_company(newsroom, "Nike, Inc.")
    refute RecordingStudioCompany.can?(:create, newsroom, actor: owner)

    trash(nike)
    refute RecordingStudioCompany.can?(:create, newsroom, actor: owner)
  end

  test "can create stays true on an agency with companies" do
    northwind = agency
    create_company(northwind, "Nike, Inc.")

    assert RecordingStudioCompany.can?(:create, northwind, actor: owner)
    refute RecordingStudioCompany.can?(:create, workspace, actor: owner)
  end

  test "can update and trash only live companies; can restore only trashed ones" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.")
    viewer = grant(newsroom, create_user("viewer"), "view")

    assert RecordingStudioCompany.can?(:update, nike, actor: owner)
    assert RecordingStudioCompany.can?(:trash, nike, actor: owner)
    refute RecordingStudioCompany.can?(:restore, nike, actor: owner)
    refute RecordingStudioCompany.can?(:update, nike, actor: viewer)
    refute RecordingStudioCompany.can?(:trash, nike, actor: viewer)

    trash(nike)

    refute RecordingStudioCompany.can?(:update, nike, actor: owner)
    refute RecordingStudioCompany.can?(:trash, nike, actor: owner)
    assert RecordingStudioCompany.can?(:restore, nike, actor: owner)
    refute RecordingStudioCompany.can?(:restore, nike, actor: viewer)
  end

  test "can view follows accessible" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.")
    viewer = grant(newsroom, create_user("viewer"), "view")
    stranger = create_user("stranger")

    assert RecordingStudioCompany.can?(:view, nike, actor: viewer)
    assert RecordingStudioCompany.can?(:view, newsroom, actor: viewer)
    refute RecordingStudioCompany.can?(:view, nike, actor: stranger)
    refute RecordingStudioCompany.can?(:view, nike, actor: nil)
  end

  test "can rejects unknown actions" do
    error = assert_raises(ArgumentError) { RecordingStudioCompany.can?(:delete, press_centre, actor: owner) }

    assert_equal "Unknown action :delete; expected one of view, create, update, trash, restore", error.message
  end

  private

  # Skips the slot validation, as rows written before a parent type switched to allow: :one would.
  def record_unchecked_company(parent, name)
    recording = RecordingStudio::Recording.new(
      root_recording: parent.root_recording,
      parent_recording: parent,
      recordable: RecordingStudioCompany::Company.create!(name:)
    )
    recording.save!(validate: false)
    recording
  end
end
