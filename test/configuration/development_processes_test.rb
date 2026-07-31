require "test_helper"

class DevelopmentProcessesTest < ActiveSupport::TestCase
  test "the Tailwind watcher stays alive without an attached terminal" do
    procfile = Rails.root.join("Procfile.dev").read

    assert_match(
      /^css: bin\/rails tailwindcss:watch\[always\]$/,
      procfile
    )
  end
end
