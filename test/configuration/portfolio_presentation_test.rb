require "test_helper"
require "json"
require "yaml"

class PortfolioPresentationTest < ActiveSupport::TestCase
  test "Codespaces configuration starts SlotGuard with PostgreSQL" do
    configuration = JSON.parse(
      Rails.root
        .join(".devcontainer/devcontainer.json")
        .read
    )
    compose = YAML.safe_load_file(
      Rails.root.join(".devcontainer/compose.yaml")
    )
    dockerfile = Rails.root
      .join(".devcontainer/Dockerfile")
      .read

    assert_equal "app", configuration.fetch("service")
    assert_includes configuration.fetch("forwardPorts"), 3000
    assert_includes configuration.fetch("postStartCommand"),
      "bin/rails server -b 0.0.0.0"
    assert compose.fetch("services").key?("db")
    assert_equal "postgres:17",
      compose.dig("services", "db", "image")
    assert_includes dockerfile,
      "mcr.microsoft.com/devcontainers/ruby:4-bookworm"
  end

  test "README presents the on-demand Codespaces demo honestly" do
    readme = Rails.root.join("README.md").read

    assert_includes readme,
      "https://codespaces.new/MichalPlanetaDev/slot_guard"
    assert_includes readme,
      "public/slotguard-preview.svg"
    assert_includes readme,
      "temporary development environment"
    refute_includes readme, "onrender.com"
    refute_includes readme, "demo@slotguard.app"
  end
end
