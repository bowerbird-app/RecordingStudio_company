# frozen_string_literal: true

require_relative "support"

class CompanyDeclarationTest < ActiveSupport::TestCase
  include CompanyTestSupport

  COMPANY_TYPE = "RecordingStudioCompany::Company"

  test "company is a declared non-root recordable with company labels" do
    declaration = RecordingStudio.recordable_declarations.fetch(COMPANY_TYPE)

    assert_equal false, declaration.root?
    assert_equal "Company", RecordingStudio.recordable_type_label(COMPANY_TYPE)
    refute_includes RecordingStudio.root_recordable_types, COMPANY_TYPE
    assert_equal %w[Workspace PressCentre Agency], RecordingStudio.root_recordable_types
  end

  test "company cannot be created as a root recording" do
    company = RecordingStudioCompany::Company.create!(name: "Nike, Inc.")

    assert_raises(RecordingStudio::RootNotAllowed) { RecordingStudio.root_recording_for(company) }
  end

  test "companies capability is registered with company as its child recordable" do
    registration = RecordingStudio.registered_capabilities.fetch(:companies)

    assert_equal "recording_studio_company", registration[:source]
    assert_equal [COMPANY_TYPE], registration[:child_recordables]
  end

  test "allowed parents are exactly the types that include companies" do
    assert_equal %w[Agency PressCentre Project], RecordingStudio.allowed_parent_types_for(COMPANY_TYPE)
    assert_equal({ allow: :one }, RecordingStudio.capability_options(:companies, for: "PressCentre"))
    assert_equal({ allow: :many }, RecordingStudio.capability_options(:companies, for: "Agency"))
    assert_equal({ allow: :one }, RecordingStudio.capability_options(:companies, for: "Project"))
    refute RecordingStudio.capability_enabled?(:companies, for: "Workspace")
  end

  test "allowance reads each parent type's choice" do
    newsroom = press_centre
    northwind = agency

    assert_equal :one, RecordingStudioCompany.allowance(newsroom)
    assert_equal :many, RecordingStudioCompany.allowance(northwind)
    assert_equal :one, RecordingStudioCompany.allowance(project(northwind))
    assert_nil RecordingStudioCompany.allowance(workspace)
  end

  test "workspace cannot parent a company" do
    studio = workspace

    error = assert_raises(RecordingStudio::InvalidParent) do
      RecordingStudio.record!(
        action: "created",
        recordable: RecordingStudioCompany::Company.new(name: "Nike, Inc."),
        root_recording: studio,
        parent_recording: studio,
        actor: owner
      )
    end
    assert_equal "RecordingStudioCompany::Company cannot be recorded under Workspace", error.message

    error = assert_raises(RecordingStudioCompany::ParentNotAllowed) { create_company(studio, "Nike, Inc.") }
    assert_equal "Workspace does not hold companies", error.message
    assert_equal 0, company_children(studio).count
  end

  test "companies to requires allow one or many" do
    error = assert_raises(RecordingStudioCompany::ConfigurationError) { RecordingStudio::Capabilities::Companies.to }
    assert_equal "Companies need allow: :one or allow: :many (got nil)", error.message

    error = assert_raises(RecordingStudioCompany::ConfigurationError) do
      RecordingStudio::Capabilities::Companies.to(allow: :two)
    end
    assert_equal "Companies need allow: :one or allow: :many (got :two)", error.message

    error = assert_raises(RecordingStudioCompany::ConfigurationError) do
      RecordingStudio::Capabilities::Companies.to(allow: :one, limit: 2)
    end
    assert_equal "Unknown companies option(s): limit", error.message
  end

  test "configuration errors are argument errors" do
    assert_operator RecordingStudioCompany::ConfigurationError, :<, ArgumentError
  end

  test "slots stay private to the gem" do
    assert_raises(NameError) { RecordingStudioCompany::Slots }
  end

  test "the engine registers company after the host replaces recordable types" do
    configured = RecordingStudio.configuration.recordable_types
    RecordingStudio.configuration.recordable_types = configured - [COMPANY_TYPE]

    registration_initializer.run(Rails.application)

    assert_includes RecordingStudio.configuration.recordable_types, COMPANY_TYPE
    assert_nothing_raised { slots.verify! }
  ensure
    RecordingStudio.configuration.recordable_types = configured
  end

  test "boot check names a missing company type" do
    configured = RecordingStudio.configuration.recordable_types
    RecordingStudio.configuration.recordable_types = configured - [COMPANY_TYPE]

    error = assert_raises(RecordingStudioCompany::ConfigurationError) { slots.verify! }
    assert_equal %(Add "RecordingStudioCompany::Company" to config.recordable_types), error.message
  ensure
    RecordingStudio.configuration.recordable_types = configured
  end

  test "boot check rejects a parent type enabled without a valid allowance" do
    RecordingStudio.set_capability_options(:companies, on: "Agency")
    error = assert_raises(RecordingStudioCompany::ConfigurationError) { slots.verify! }
    assert_equal "Companies on Agency need allow: :one or allow: :many (got nil)", error.message

    RecordingStudio.set_capability_options(:companies, on: "Agency", allow: :few)
    error = assert_raises(RecordingStudioCompany::ConfigurationError) { slots.verify! }
    assert_equal "Companies on Agency need allow: :one or allow: :many (got :few)", error.message
  ensure
    RecordingStudio.set_capability_options(:companies, on: "Agency", allow: :many)
  end

  test "preparing again does not add a second slot validation" do
    Rails.application.reloader.prepare!
    Rails.application.reloader.prepare!

    slot_callbacks = RecordingStudio::Recording._validate_callbacks.count do |callback|
      callback.filter == :recording_studio_company_slot_free
    end
    assert_equal 1, slot_callbacks
  end

  test "attachments can be trashed so a removed logo keeps its place" do
    assert RecordingStudio.capability_enabled?(:trashable, for: "RecordingStudioAttachable::Attachment")
    assert RecordingStudio.capability_enabled?(:trashable, for: COMPANY_TYPE)
    assert RecordingStudio.capability_enabled?(:attachable, for: COMPANY_TYPE)
  end

  test "company logos accept one image of up to ten megabytes" do
    options = RecordingStudio.capability_options(:attachable, for: COMPANY_TYPE)

    assert_equal ["image/*"], options[:allowed_content_types]
    assert_equal [:image], options[:enabled_attachment_kinds]
    assert_equal 10.megabytes, options[:max_file_size]
    assert_equal 1, options[:max_file_count]
    assert_equal({ upload: :edit, revise: :edit, remove: :edit, restore: :edit }, options[:auth_roles])
  end

  test "company leaves duplicatable orderable and accessible to other gems" do
    %i[duplicatable orderable accessible].each do |capability|
      refute RecordingStudio.capability_enabled?(capability, for: COMPANY_TYPE), "#{capability} should be off"
    end
  end

  private

  def registration_initializer
    RecordingStudioCompany::Engine.initializers.find { |item| item.name == "recording_studio_company.recordable_types" }
  end

  def slots
    RecordingStudioCompany.const_get(:Slots)
  end
end
