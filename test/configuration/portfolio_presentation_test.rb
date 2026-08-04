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
    features = configuration.fetch("features")

    assert_equal "app", configuration.fetch("service")
    assert_includes configuration.fetch("forwardPorts"), 3000
    assert_includes configuration.fetch("postStartCommand"),
      "bin/rails server -b 0.0.0.0"
    assert compose.fetch("services").key?("db")
    assert_equal "postgres:17",
      compose.dig("services", "db", "image")
    assert_includes dockerfile,
      "mcr.microsoft.com/devcontainers/base:bookworm"
    assert_equal(
      { "version" => "4.0.6" },
      features.fetch("ghcr.io/devcontainers/features/ruby:2")
    )
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

  test "Codespaces includes SSH support for CLI maintenance" do
    configuration = JSON.parse(
      Rails.root
        .join(".devcontainer/devcontainer.json")
        .read
    )

    assert configuration
      .fetch("features")
      .key?("ghcr.io/devcontainers/features/sshd:1")
  end
  test "Codespaces allows forwarded application ports" do
    development_configuration = Rails.root
      .join("config/environments/development.rb")
      .read

    assert_includes development_configuration,
      'config.hosts << /\A[a-z0-9-]+-\d+\.app\.github\.dev\z/'
  end
end
