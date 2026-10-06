# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "generators/recording_studio_company/migrations/migrations_generator"

class MigrationsGeneratorTest < Minitest::Test
  def test_copies_the_companies_migration_with_a_host_timestamp
    Dir.mktmpdir do |dir|
      run_generator(dir)

      copied = Dir.glob(File.join(dir, "db/migrate/*.rb")).map { |path| File.basename(path) }
      assert_equal 1, copied.size
      assert_match(/\A\d{14}_create_recording_studio_companies\.rb\z/, copied.first)
      refute_equal "20261005000001_create_recording_studio_companies.rb", copied.first
    end
  end

  def test_copied_migration_creates_the_snapshot_table
    Dir.mktmpdir do |dir|
      run_generator(dir)

      migration = File.read(Dir.glob(File.join(dir, "db/migrate/*_create_recording_studio_companies.rb")).first)
      assert_includes migration, "class CreateRecordingStudioCompanies < ActiveRecord::Migration[8.1]"
      assert_includes migration, "create_table :recording_studio_companies, id: :uuid do |t|"
      %w[legal_name website_url email phone].each do |column|
        assert_includes migration, "t.string :#{column}\n"
      end
      assert_includes migration, "t.string :name, null: false"
      assert_includes migration, "t.text :description"
      assert_includes migration, "t.date :founded_on"
      assert_includes migration, "t.datetime :created_at, null: false"
      refute_includes migration, "t.timestamps"
      refute_includes migration, "updated_at, null"
    end
  end

  def test_running_twice_skips_the_existing_migration
    Dir.mktmpdir do |dir|
      run_generator(dir)
      messages = run_generator(dir)

      assert_equal 1, Dir.glob(File.join(dir, "db/migrate/*_create_recording_studio_companies.rb")).size
      assert_includes messages, ["  skip  create_recording_studio_companies.rb (already exists)", :yellow]
    end
  end

  def test_does_not_copy_template_migrations
    Dir.mktmpdir do |dir|
      run_generator(dir)

      assert_empty Dir.glob(File.join(dir, "db/migrate/*_pages.rb"))
    end
  end

  private

  def run_generator(dir)
    messages = []
    generator = RecordingStudioCompany::Generators::MigrationsGenerator.new([], { quiet: true }, destination_root: dir)
    generator.stub(:say, ->(message, color = nil) { messages << [message, color] }) do
      generator.stub(:sleep, nil) { generator.invoke_all }
    end
    messages
  end
end
