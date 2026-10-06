# frozen_string_literal: true

require_relative "lib/recording_studio_company/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_company"
  spec.version     = RecordingStudioCompany::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_company"
  spec.summary     = "Companies for Recording Studio"
  spec.description = "A Recording Studio addon that keeps company profiles (name, legal name, contact details, " \
                     "founding date, and logo) under any recording a host app allows."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_company"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_company/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
end
