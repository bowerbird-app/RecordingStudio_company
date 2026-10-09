# frozen_string_literal: true

require "test_helper"

class RecordingStudioCompanyTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.2.2", ::RecordingStudioCompany::VERSION
  end

  def test_gemspec_points_at_the_company_repository
    spec = Gem::Specification.load(File.expand_path("../recording_studio_company.gemspec", __dir__))

    assert_equal "recording_studio_company", spec.name
    assert_equal "https://github.com/bowerbird-app/RecordingStudio_company", spec.homepage
    assert_equal "https://github.com/bowerbird-app/RecordingStudio_company", spec.metadata["source_code_uri"]
    assert_equal "https://github.com/bowerbird-app/RecordingStudio_company/blob/main/CHANGELOG.md",
                 spec.metadata["changelog_uri"]
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioCompany::Engine
  end

  def test_gemspec_pins_recording_studio_4_2
    gemspec = File.read(File.expand_path("../recording_studio_company.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
  end

  def test_gemspec_depends_on_the_capability_gems_companies_use
    spec = Gem::Specification.load(File.expand_path("../recording_studio_company.gemspec", __dir__))
    requirements = spec.runtime_dependencies.to_h { |dependency| [dependency.name, dependency.requirement.to_s] }

    assert_equal(
      {
        "flat_pack" => ">= 0.1.200",
        "rails" => "~> 8.1.0",
        "recording_studio" => "~> 4.2",
        "recording_studio_accessible" => "~> 0.13",
        "recording_studio_attachable" => "~> 0.13",
        "recording_studio_trashable" => "~> 0.6"
      },
      requirements
    )
  end

  def test_gemspec_excludes_cursor_config
    spec = Gem::Specification.load(File.expand_path("../recording_studio_company.gemspec", __dir__))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files, "gemspec must not package .cursor/ (got #{cursor_files.inspect})"
  end

  def test_cursor_environment_is_repo_managed_without_snapshot
    path = File.expand_path("../.cursor/environment.json", __dir__)
    json = JSON.parse(File.read(path))

    assert_equal "recording-studio-gem-template", json["name"]
    assert_equal ".cursor/install.sh", json["install"]
    assert_equal ".cursor/start.sh", json["start"]
    refute json.key?("snapshot"), "snapshot pins a Personal build and skips install"
    refute json.key?("agentCanUpdateSnapshot")
  end

  def test_cursor_install_still_fetches_skills
    install_script = File.read(File.expand_path("../.cursor/install.sh", __dir__))

    assert_includes install_script, "fetch-skills.sh"
  end

  def test_dummy_gemfile_pins_verified_4x_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.4.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.13.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.13.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.6.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.5.1"'
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.213"'
    refute_includes gemfile, 'tag: "v0.10.1"'
    refute_includes gemfile, "recording_studio/v3.0.0"
    refute_includes gemfile, 'tag: "v4.2.2"'
    refute_includes gemfile, 'tag: "v4.2.1"'
    refute_includes gemfile, 'tag: "v4.2.0"'
    refute_includes gemfile, 'tag: "v0.11.1"'
    refute_includes gemfile, 'tag: "v0.7.1"'
    refute_includes gemfile, 'tag: "v0.4.4"'
    refute_includes gemfile, 'tag: "v0.9.1"'
    refute_includes gemfile, 'tag: "v0.5.0"'
    refute_includes gemfile, 'tag: "v0.1.203"'
    refute_includes gemfile, 'tag: "v0.1.177"'
    refute_includes gemfile, 'tag: "v0.1.133"'
    refute_includes gemfile, 'tag: "0.3.1"'
  end

  def test_dummy_schema_includes_accessible_depends_on_recording_id
    schema = File.read(File.expand_path("dummy/db/schema.rb", __dir__))
    migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20260911024811_add_depends_on_recording_id_to_recording_studio_accesses.rb",
        __dir__
      )
    )

    assert_includes schema, 't.uuid "depends_on_recording_id"'
    assert_includes schema, "index_recording_studio_accesses_on_depends_on_recording_id"
    assert_includes migration, "add_column :recording_studio_accesses, :depends_on_recording_id, :uuid"
    assert_includes schema, 'create_table "recording_studio_access_invitations"'
    assert_includes schema, "idx_rs_access_invitations_token_digest"
    invitation_migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20261001000011_create_recording_studio_access_invitations.rb",
        __dir__
      )
    )
    assert_includes invitation_migration, "create_table :recording_studio_access_invitations"
  end

  def test_dummy_schema_includes_attachable_libraries_and_placements
    schema = File.read(File.expand_path("dummy/db/schema.rb", __dir__))
    libraries_migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20261009100000_create_recording_studio_attachable_libraries.rb",
        __dir__
      )
    )
    placements_migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20261009100001_create_recording_studio_attachable_placements.rb",
        __dir__
      )
    )

    assert_includes schema, 'create_table "recording_studio_attachable_libraries"'
    assert_includes schema, 'create_table "recording_studio_attachable_placements"'
    assert_includes schema, 't.uuid "attachment_recording_id", null: false'
    assert_includes libraries_migration, "create_table :recording_studio_attachable_libraries"
    assert_includes placements_migration, "create_table :recording_studio_attachable_placements"
  end

  def test_template_does_not_ship_copied_core_hooks_or_base_service
    refute File.exist?(File.expand_path("../lib/recording_studio_company/hooks.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_company/services/base_service.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_company/services/example_service.rb", __dir__))
  end

  def test_example_capability_is_gone
    refute File.exist?(File.expand_path("../lib/recording_studio_company/capabilities/example.rb", __dir__))
    refute RecordingStudio.registered_capabilities.key?(:example)
  end

  def test_dummy_app_uses_recording_studio_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "include RecordingStudio::UsesDefaultLayout"
    assert_includes controller_source, '"recording_studio/default_layout"'
    assert_includes controller_source, "devise_controller? ? \"application\""
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))
  end

  def test_dummy_login_layout_keeps_flatpack_assets_without_tight_main_offset
    application_layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes application_layout, '<html data-theme="rounded">'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/rich_text"'
    assert_includes application_layout, "javascript_importmap_tags"
    assert_includes application_layout, "min-h-screen"
    refute_includes application_layout, "mt-28"
    refute_includes application_layout, "flat_pack_sidebar"
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "../../../vendor/engines/flat_pack/app/components"
    assert_includes tailwind_source, "../../../vendor/engines/recording_studio/app/views"
    refute_includes tailwind_source, "vendor/bundle/**/flatpack/app/components"
    refute_includes tailwind_source, "recordingstudio-*"
    refute_includes tailwind_source, "@theme"
    refute_includes tailwind_source, ":root {"
    refute_includes tailwind_source, "--color-fp-primary"

    head_partial = File.read(
      File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__)
    )
    assert_includes head_partial, 'stylesheet_link_tag "flat_pack/application"'

    rake_task = File.read(File.expand_path("dummy/lib/tasks/tailwindcss.rake", __dir__))
    assert_includes rake_task, "FlatPack::Engine.root"
    assert_includes rake_task, "RecordingStudio::Engine.root"
    assert_includes rake_task, "tailwindcss:link_engine_sources"
  end

  def test_recording_studio_keeps_strict_recordable_declarations_enabled
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "config.require_recordable_declarations = true"
    assert_includes initializer_source, <<~RUBY.gsub(/^/, "  ")
      config.recordable_types = [
        "Workspace", "Folder", "Page",
        "PressCentre", "Agency", "Project",
        "RecordingStudioCompany::Company",
        "RecordingStudioAttachable::Attachment",
        "RecordingStudioAttachable::Library",
        "RecordingStudioAttachable::Placement"
      ]
    RUBY
    refute_includes initializer_source, "config.include_children"
    refute_includes initializer_source, "config.features."
    refute_includes initializer_source, "v3"
  end

  def test_dummy_readme_describes_the_company_demo
    readme_source = File.read(File.expand_path("dummy/README.md", __dir__))

    assert_includes readme_source, "This Rails app is the host used to develop and test RecordingStudioCompany"
    assert_includes readme_source, "/recording_studio_company"
    assert_includes readme_source, "redirects to `/`"
    ["Nike Newsroom", "Northwind", "Harbour fit-out", "Acme Engineering Pty Ltd"].each do |name|
      assert_includes readme_source, name
    end
    refute_includes readme_source, "addon template"
    refute_includes readme_source, "flat_pack_sidebar"
  end

  def test_readme_documents_companies
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "`RecordingStudioCompany::Company` is a generic, non-root recordable"
    assert_includes readme, "It is not tied to Workspace or to any root type"
    assert_includes readme, "include RecordingStudio::Capabilities::Companies.to(allow: :one)"
    assert_includes readme, "include RecordingStudio::Capabilities::Companies.to(allow: :many)"
    assert_includes readme, '"RecordingStudioCompany::Company"'
    assert_includes readme, "Store the recording id, `company.id`"
    assert_includes readme, "Brands are not in this gem"
    assert_includes readme, "People are not in this gem"
    assert_includes readme, "Locations are not in this gem"
    assert_includes readme, "# Not part of this gem. A future brand gem could list Unilever's brands here."
    assert_includes readme, "bin/rails generate recording_studio_company:install"
    assert_includes readme, "bundle exec rake test:all"
    assert_operator readme.index("## Install"), :<, readme.index("## Use companies")
    refute_includes readme, "—"
    refute_includes readme, "ExampleService"
    refute_includes readme, "Internal template"
  end

  def test_readme_headings_use_sentence_case
    readme = File.read(File.expand_path("../README.md", __dir__))
    headings = readme.scan(/^##+ (.+)$/).flatten

    refute_empty headings
    headings.each do |heading|
      later_words = heading.split.drop(1).reject { |word| word.start_with?("`") }

      assert later_words.none? { |word| word.match?(/\A[A-Z][a-z]/) }, "Use sentence case in #{heading.inspect}"
    end
  end

  def test_changelog_starts_at_the_first_company_release
    changelog = File.read(File.expand_path("../CHANGELOG.md", __dir__))

    assert_includes changelog, "## [0.1.0] - 2026-10-06"
    assert_includes changelog, "The repository started from the Recording Studio gem template."
    assert_includes changelog, "`RecordingStudioCompany::Company`"
    assert_includes changelog, "## [0.2.0] - 2026-10-07"
    assert_includes changelog, "bin/rails generate recording_studio_company:migrations"
    assert_includes changelog, "`legal_name`, `email`, `phone`, and `founded_on`"
    assert_includes changelog, "The edit form's button says Update."
    assert_includes changelog, "Pin `flat_pack` at `v0.1.200` or newer."
    assert_includes changelog, "## [0.2.1] - 2026-10-08"
    assert_includes changelog, "## [0.2.2] - 2026-10-09"
    assert_includes changelog, "The edit form's button says Save."
    refute_match(/## \[0\.3\./, changelog)
  end

  def test_dummy_home_page_links_to_the_company_pages
    view_source = File.read(File.expand_path("dummy/app/views/home/index.html.erb", __dir__))

    assert_includes view_source, 'title: "Company demo"'
    assert_includes view_source, "recording_studio_company.recording_companies_path(parent)"
    assert_includes view_source, "recording_studio_company_logo"
    assert_includes view_source, "FlatPack::Card::Component"
    assert_includes view_source, "dummy_page_nav"
    refute_includes view_source, "Template Demo"
    refute_includes view_source, "Next steps"
    refute_includes view_source, "FlatPack::Breadcrumb::Component"
  end

  def test_dummy_docs_pages_use_minimal_flatpack_documentation_components
    docs_view_paths = Dir[File.expand_path("dummy/app/views/docs/*.html.erb", __dir__)].reject do |view_path|
      File.basename(view_path).start_with?("_")
    end
    refute_empty docs_view_paths

    docs_view_paths.each do |view_path|
      view_source = File.read(view_path)

      assert_includes view_source, "dummy_page_nav"
      assert_includes view_source, "FlatPack::PageTitle::Component"
      refute_includes view_source, "FlatPack::Card::Component"
      refute_includes view_source, "FlatPack::Breadcrumb::Component"
    end

    methods_view = File.read(File.expand_path("dummy/app/views/docs/methods.html.erb", __dir__))
    assert_includes methods_view, "FlatPack::SectionTitle::Component"
    assert_includes methods_view, "FlatPack::CodeBlock::Component"

    gem_views_view = File.read(File.expand_path("dummy/app/views/docs/gem_views.html.erb", __dir__))
    assert_includes gem_views_view, "FlatPack::Table::Component"
    refute_includes gem_views_view, "FlatPack::List::Component"

    recordable_types_view = File.read(File.expand_path("dummy/app/views/docs/recordable_types.html.erb", __dir__))
    assert_includes recordable_types_view, "FlatPack::List::Component"
    refute_includes recordable_types_view, "v3 parent/root"

    recordings_tree_view = File.read(File.expand_path("dummy/app/views/docs/recordings_tree.html.erb", __dir__))
    assert_includes recordings_tree_view, "FlatPack::Tree::Component"
    refute_includes recordings_tree_view, "Current structure"
    refute_includes recordings_tree_view, "This tree is generated from RecordingStudio::Recording records"
  end

  def test_dummy_recordings_tree_view_omits_structure_section_copy
    recordings_tree_view = File.read(File.expand_path("dummy/app/views/docs/recordings_tree.html.erb", __dir__))

    assert_includes recordings_tree_view, 'title: "Recordings tree"'
    assert_includes recordings_tree_view, "FlatPack::Tree::Component"
    recording_tree_partial = File.read(File.expand_path("dummy/app/views/docs/_recording_tree_node.html.erb", __dir__))
    assert_includes recording_tree_partial, "parent_builder.node"
    refute_includes recordings_tree_view, "Current structure"
    refute_includes recordings_tree_view, "This tree is generated from RecordingStudio::Recording records"
  end

  def test_engine_does_not_ship_a_home_view
    view_path = File.expand_path("../app/views/recording_studio_company/home/index.html.erb", __dir__)

    refute File.exist?(view_path)
  end
end
