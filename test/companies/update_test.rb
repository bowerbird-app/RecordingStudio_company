# frozen_string_literal: true

require_relative "support"

class CompanyUpdateTest < ActiveSupport::TestCase
  include CompanyTestSupport

  test "a change revises the company and keeps its recording id" do
    nike = create_company(press_centre, "Nike", website_url: "nike.com")
    first_snapshot = nike.recordable

    revised = RecordingStudioCompany.update(nike, actor: owner, name: "Nike, Inc.", description: "Athletic footwear.")

    assert_equal nike.id, revised.id
    assert_not_equal first_snapshot.id, revised.recordable_id
    assert_equal "Nike, Inc.", revised.recordable.name
    assert_equal "Athletic footwear.", revised.recordable.description
    assert_equal "nike.com", revised.recordable.website_url
    assert_equal "Nike", first_snapshot.reload.name
    assert_equal %w[created updated], revised.events.reorder(:occurred_at, :created_at).map(&:action)
    assert_equal [first_snapshot, revised.recordable], revised.recordables
  end

  test "unchanged fields write nothing" do
    nike = create_company(press_centre, "Nike, Inc.", website_url: "nike.com")

    assert_no_difference -> { RecordingStudioCompany::Company.count } do
      assert_no_difference -> { RecordingStudio::Event.count } do
        same = RecordingStudioCompany.update(nike, actor: owner, name: " Nike, Inc. ", website_url: "nike.com")

        assert_equal nike, same
        assert_equal nike.recordable_id, same.recordable_id
      end
    end
  end

  test "nil clears an optional field" do
    nike = create_company(press_centre, "Nike, Inc.", website_url: "https://about.nike.com")

    revised = RecordingStudioCompany.update(nike, actor: owner, website_url: nil)

    assert_nil revised.recordable.website_url
    assert_equal "Nike, Inc.", revised.recordable.name
  end

  test "an invalid change raises with the unsaved company and writes nothing" do
    nike = create_company(press_centre, "Nike, Inc.")

    assert_no_difference -> { RecordingStudioCompany::Company.count } do
      error = assert_raises(RecordingStudioCompany::Invalid) do
        RecordingStudioCompany.update(nike, actor: owner, name: "", description: "d" * 5_001)
      end

      assert_equal "Name can't be blank and Description is too long (maximum is 5000 characters)", error.message
      assert_equal "d" * 5_001, error.record.description
    end
    assert_equal "Nike, Inc.", nike.reload.recordable.name
  end

  test "updating a trashed company raises" do
    nike = trash(create_company(press_centre, "Nike, Inc."))

    error = assert_raises(RecordingStudioCompany::Trashed) do
      RecordingStudioCompany.update(nike, actor: owner, name: "Nike")
    end

    assert_equal "Restore Nike, Inc. before changing it", error.message
    assert_equal nike, error.company
  end

  test "updating a company loaded before it was trashed raises" do
    nike = create_company(press_centre, "Nike, Inc.")
    RecordingStudio::Recording.find(nike.id).recording_studio_trashable_trash!(actor: owner)

    assert_raises(RecordingStudioCompany::Trashed) { RecordingStudioCompany.update(nike, actor: owner, name: "Nike") }
  end

  test "updating needs edit access on the company" do
    newsroom = press_centre
    nike = create_company(newsroom, "Nike, Inc.")
    viewer = grant(newsroom, create_user("viewer"), "view")

    error = assert_raises(RecordingStudioCompany::NotAuthorized) do
      RecordingStudioCompany.update(nike, actor: viewer, name: "Nike")
    end

    assert_equal "Changing this company needs edit access", error.message
    assert_equal "Nike, Inc.", nike.reload.recordable.name
  end

  test "update takes company recordings only" do
    newsroom = press_centre

    error = assert_raises(ArgumentError) { RecordingStudioCompany.update(newsroom, actor: owner, name: "Nike") }

    assert_equal "Expected a company recording; load one with RecordingStudioCompany.find(id)", error.message
  end
end
