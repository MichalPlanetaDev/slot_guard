require "test_helper"
require "json"
require "yaml"

class PortfolioReleaseTest < ActiveSupport::TestCase
  test "Render Blueprint keeps secrets outside Git" do
    blueprint = YAML.safe_load_file(
      Rails.root.join("render.yaml")
    )
    service = blueprint.fetch("services").sole
    environment = service.fetch("envVars").index_by {
      |entry| entry.fetch("key")
    }

    assert_equal "web", service.fetch("type")
    assert_equal "docker", service.fetch("runtime")
    assert_equal "free", service.fetch("plan")
    assert_equal "/up", service.fetch("healthCheckPath")
    assert_equal false,
      environment.fetch("DATABASE_URL").fetch("sync")
    assert_equal false,
      environment.fetch("RAILS_MASTER_KEY").fetch("sync")
    assert_equal "true",
      environment.fetch("DEMO_MODE").fetch("value")
  end

  test "Codespaces configuration is valid and includes PostgreSQL" do
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

  test "README exposes the live demo and Codespaces entry points" do
    readme = Rails.root.join("README.md").read

    assert_includes readme,
      "https://slotguard-michalplanetadev.onrender.com"
    assert_includes readme,
      "https://codespaces.new/MichalPlanetaDev/slot_guard"
    assert_includes readme,
      "public/slotguard-preview.svg"
    assert_includes readme,
      Demo::Reset::OWNER_EMAIL
  end
end
