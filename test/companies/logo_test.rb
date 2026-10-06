# frozen_string_literal: true

require_relative "support"

class CompanyLogoTest < ActiveSupport::TestCase
  include CompanyTestSupport

  setup do
    @nike = create_company(press_centre, "Nike, Inc.")
  end

  test "the first logo is one attachment named logo under the company" do
    returned = RecordingStudioCompany.set_logo(@nike, signed_blob_id: png_blob("nike.png").signed_id, actor: owner)

    logo = RecordingStudioCompany.logo(@nike)
    assert_equal @nike, returned
    assert_equal [logo.id], logo_children(@nike).pluck(:id)
    assert_equal "logo", logo.recordable.name
    assert_equal "nike.png", logo.recordable.original_filename
    assert_equal "image", logo.recordable.attachment_kind
    assert_equal @nike.root_recording, logo.root_recording
  end

  test "a second logo replaces the file and keeps the attachment recording" do
    RecordingStudioCompany.set_logo(@nike, signed_blob_id: png_blob("first.png").signed_id, actor: owner)
    first = RecordingStudioCompany.logo(@nike)

    RecordingStudioCompany.set_logo(@nike, signed_blob_id: png_blob("second.png").signed_id, actor: owner)
    second = RecordingStudioCompany.logo(@nike)

    assert_equal first.id, second.id
    assert_not_equal first.recordable_id, second.recordable_id
    assert_equal "second.png", second.recordable.original_filename
    assert_equal "logo", second.recordable.name
    assert_equal 1, logo_children(@nike).count
  end

  test "removing the logo trashes it, and the next logo revives the same attachment" do
    RecordingStudioCompany.set_logo(@nike, signed_blob_id: png_blob("first.png").signed_id, actor: owner)
    first = RecordingStudioCompany.logo(@nike)

    RecordingStudioCompany.remove_logo(@nike, actor: owner)

    assert_nil RecordingStudioCompany.logo(@nike)
    assert_predicate first.reload.trashed_at, :present?

    RecordingStudioCompany.set_logo(@nike, signed_blob_id: png_blob("again.png").signed_id, actor: owner)
    revived = RecordingStudioCompany.logo(@nike)

    assert_equal first.id, revived.id
    assert_equal "again.png", revived.recordable.original_filename
    assert_equal 1, logo_children(@nike).count
  end

  test "removing a logo that is not there does nothing" do
    assert_no_difference -> { RecordingStudio::Event.count } do
      assert_equal @nike, RecordingStudioCompany.remove_logo(@nike, actor: owner)
    end
  end

  test "a non-image file is rejected and nothing is added" do
    assert_no_difference -> { RecordingStudioAttachable::Attachment.count } do
      assert_no_difference -> { logo_children(@nike).count } do
        error = assert_raises(RecordingStudioCompany::LogoRejected) do
          RecordingStudioCompany.set_logo(@nike, signed_blob_id: text_blob.signed_id, actor: owner)
        end

        assert_equal 'Blob content type "text/plain" is not allowed. Allowed types: image/*', error.message
      end
    end
  end

  test "attachable's own upload cannot add a second attachment under a company" do
    RecordingStudioCompany.set_logo(@nike, signed_blob_id: png_blob.signed_id, actor: owner)

    result = RecordingStudioAttachable::Services::RecordAttachmentUpload.call(
      parent_recording: @nike, signed_blob_id: png_blob("extra.png").signed_id, actor: owner
    )

    assert_predicate result, :failure?
    assert_equal "Validation failed: A company can have only one logo", result.error
    assert_equal 1, logo_children(@nike).count
  end

  test "a removed logo still holds the place against attachable's own upload" do
    RecordingStudioCompany.set_logo(@nike, signed_blob_id: png_blob.signed_id, actor: owner)
    RecordingStudioCompany.remove_logo(@nike, actor: owner)

    result = RecordingStudioAttachable::Services::RecordAttachmentUpload.call(
      parent_recording: @nike, signed_blob_id: png_blob("extra.png").signed_id, actor: owner
    )

    assert_equal "Validation failed: A company can have only one logo", result.error
  end

  test "logo changes on a trashed company raise" do
    trash(@nike)

    error = assert_raises(RecordingStudioCompany::Trashed) do
      RecordingStudioCompany.set_logo(@nike, signed_blob_id: png_blob.signed_id, actor: owner)
    end
    assert_equal "Restore Nike, Inc. before changing it", error.message
    assert_raises(RecordingStudioCompany::Trashed) { RecordingStudioCompany.remove_logo(@nike, actor: owner) }
  end

  test "logo changes need edit access on the company" do
    viewer = grant(@nike.root_recording, create_user("viewer"), "view")

    error = assert_raises(RecordingStudioCompany::NotAuthorized) do
      RecordingStudioCompany.set_logo(@nike, signed_blob_id: png_blob.signed_id, actor: viewer)
    end
    assert_equal "Changing this company needs edit access", error.message
    assert_equal 0, logo_children(@nike).count
  end

  test "trashing the company trashes its logo, and restoring brings both back" do
    RecordingStudioCompany.set_logo(@nike, signed_blob_id: png_blob.signed_id, actor: owner)
    logo = RecordingStudioCompany.logo(@nike)

    trash(@nike)
    assert_predicate logo.reload.trashed_at, :present?

    restore(@nike)
    assert_nil logo.reload.trashed_at
    assert_equal logo, RecordingStudioCompany.logo(@nike)
  end

  test "a logo removed before the company was trashed stays removed after restore" do
    RecordingStudioCompany.set_logo(@nike, signed_blob_id: png_blob.signed_id, actor: owner)
    RecordingStudioCompany.remove_logo(@nike, actor: owner)

    restore(trash(@nike))

    assert_nil RecordingStudioCompany.logo(@nike)
  end
end
