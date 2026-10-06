# frozen_string_literal: true

require "test_helper"

class RenameGemIdentityTest < Minitest::Test
  SCRIPT = File.expand_path("../bin/rename_gem", __dir__)

  def test_rename_script_rewrites_leftover_template_homepages
    load SCRIPT unless defined?(GemRenamer)
    script = File.read(SCRIPT)

    assert_equal 2, GemRenamer::LEFTOVER_HOMEPAGES.size
    assert(GemRenamer::LEFTOVER_HOMEPAGES.all? { |url| url.start_with?("https://github.com/bowerbird-app/") })
    assert_includes script, "rewrite_leftover_homepages!"
    assert_includes script, "leftover_template_identity?"
    assert_includes script, "README.md"
    assert_includes script, "CHANGELOG.md"
  end
end
