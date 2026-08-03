require "test_helper"
require "json"
require "yaml"

class PortfolioPresentationTest < ActiveSupport::TestCase
  test "Codespaces configuration includes PostgreSQL" do
    configuration = JSON.parse(
      Rails.root
        .join(".devcontainer/devcontainer.json")
        .read
    )
    compose = YAML.safe_load_file(
      Rails.root.join(".devcontainer/compose.yaml")
    )

    assert_equal "app", configuration.fetch("service")
    assert_includes configuration.fetch("forwardPorts"), 3000
    assert compose.fetch("services").key?("db")
    assert_equal "postgres:17",
      compose.dig("services", "db", "image")
  end

  test "README presents the project without an unverified live demo" do
    readme = Rails.root.join("README.md").read

    assert_includes readme,
      "https://codespaces.new/MichalPlanetaDev/slot_guard"
    assert_includes readme,
      "public/slotguard-preview.svg"
    refute_includes readme, "onrender.com"
    refute_includes readme, "demo@slotguard.app"
  end
end
