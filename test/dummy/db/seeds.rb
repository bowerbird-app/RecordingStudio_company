# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require "stringio"
require "zlib"

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

# Accessible refuses a second owner bootstrap once a root has any access, so check first.
grant_owner_access = lambda do |actor, root_recording|
  next if RecordingStudioAccessible.role_for(actor: actor, recording: root_recording)

  result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root_recording, actor: actor)
  raise "Owner access for #{root_recording.name} failed: #{result.error}" if result.failure?
end

seed_company = lambda do |actor, parent_recording, **fields|
  RecordingStudioCompany.create(
    parent_recording,
    actor: actor,
    idempotency_key: "seed:#{fields.fetch(:name).parameterize}",
    **fields
  )
end

placeholder_logo_png = lambda do
  size = 64
  center = (size - 1) / 2.0
  radius = size * 0.32
  rows = Array.new(size) do |y|
    pixels = Array.new(size) do |x|
      ((x - center)**2) + ((y - center)**2) <= radius**2 ? "\xF0\x5A\x28\xFF".b : "\x11\x11\x11\xFF".b
    end
    "\x00".b + pixels.join.b
  end
  chunk = ->(type, data) { [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N") }

  "\x89PNG\r\n\x1A\n".b +
    chunk.call("IHDR".b, [ size, size, 8, 6, 0, 0, 0 ].pack("N2C5")) +
    chunk.call("IDAT".b, Zlib::Deflate.deflate(rows.join.b)) +
    chunk.call("IEND".b, "".b)
end

user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")

press_centre = PressCentre.find_or_create_by!(name: "Nike Newsroom")
agency = Agency.find_or_create_by!(name: "Northwind")
project = Project.find_or_create_by!(name: "Harbour fit-out")

previous_actor = Current.actor
Current.actor = user

begin
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)

  press_centre_recording = RecordingStudio.root_recording_for(press_centre)
  agency_recording = RecordingStudio.root_recording_for(agency)
  grant_owner_access.call(user, press_centre_recording)
  grant_owner_access.call(user, agency_recording)
  project_recording = find_or_record_child.call(project, agency_recording, agency_recording)

  nike = seed_company.call(
    user,
    press_centre_recording,
    name: "Nike, Inc.",
    description: "Athletic footwear, apparel, equipment, and accessories.",
    website_url: "https://about.nike.com"
  )

  agency_companies = [
    seed_company.call(user, agency_recording, name: "Nike, Inc.", website_url: "https://about.nike.com"),
    seed_company.call(
      user,
      agency_recording,
      name: "Unilever",
      website_url: "https://www.unilever.com"
    ),
    seed_company.call(
      user,
      agency_recording,
      name: "Acme Coffee Pty Ltd",
      description: "A coffee roaster and Northwind client.",
      phone: "+61 2 5550 0100"
    )
  ]

  project_company = seed_company.call(
    user,
    project_recording,
    name: "Acme Engineering Pty Ltd",
    description: "The engineering contractor for the harbour fit-out."
  )

  if RecordingStudioCompany.logo(nike).nil?
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(placeholder_logo_png.call),
      filename: "nike-logo.png",
      content_type: "image/png"
    )
    RecordingStudioCompany.set_logo(nike, signed_blob_id: blob.signed_id, actor: user)
  end
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: Press centre '#{press_centre.name}' with #{nike.recordable.name}"
puts "Seeded: Agency '#{agency.name}' with #{agency_companies.map { |company| company.recordable.name }.join('; ')}"
puts "Seeded: Project '#{project.name}' with #{project_company.recordable.name}"
