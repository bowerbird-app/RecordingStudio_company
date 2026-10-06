# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "rails/test_help"
require "zlib"

# Builds parents the way the dummy host does: a root recordable, an owner granted through
# Accessible, then calls into RecordingStudioCompany as a host would.
module CompanyTestSupport
  PASSWORD = "CompanyTestPassword!2026"

  private

  def owner
    @owner ||= create_user("owner")
  end

  def create_user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: PASSWORD,
      password_confirmation: PASSWORD
    )
  end

  def press_centre(name = "Nike Newsroom")
    owned_root(PressCentre.create!(name:))
  end

  def agency(name = "Northwind")
    owned_root(Agency.create!(name:))
  end

  def workspace(name = "Studio Workspace")
    owned_root(Workspace.create!(name:))
  end

  def project(agency_recording, name = "Harbour fit-out")
    agency_recording.record(Project.new(name:), actor: owner)
  end

  def owned_root(recordable)
    root = RecordingStudio.root_recording_for(recordable)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: owner)
    raise "Owner access failed: #{result.error}" if result.failure?

    root
  end

  def grant(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(recording:, actor:, role:, manager_actor: owner)
    raise "Grant failed: #{result.error}" if result.failure?

    actor
  end

  def create_company(parent, name, **fields)
    RecordingStudioCompany.create(parent, actor: owner, name:, **fields)
  end

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

  def names(company_recordings)
    company_recordings.map { |company| company.recordable.name }
  end

  def company_children(parent)
    RecordingStudio::Recording.unscoped.where(
      parent_recording_id: parent.id,
      recordable_type: "RecordingStudioCompany::Company"
    )
  end

  def logo_children(company)
    RecordingStudio::Recording.unscoped.where(
      parent_recording_id: company.id,
      recordable_type: "RecordingStudioAttachable::Attachment"
    )
  end

  def trash(recording)
    recording.recording_studio_trashable_trash!(actor: owner)
    recording.reload
  end

  def restore(recording)
    recording.recording_studio_trashable_restore!(actor: owner)
    recording.reload
  end

  def png_blob(filename = "logo.png")
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png_bytes), filename:, content_type: "image/png")
  end

  def text_blob
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("not a logo"), filename: "notes.txt",
                                           content_type: "text/plain")
  end

  # A 2x2 opaque PNG, built here so the repository carries no binary fixture.
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
