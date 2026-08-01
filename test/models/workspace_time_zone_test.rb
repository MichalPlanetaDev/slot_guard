require "test_helper"

class WorkspaceTimeZoneTest < ActiveSupport::TestCase
  test "accepts IANA identifiers and rejects unknown zones" do
    workspace = Workspace.new(
      name: "Research Lab",
      time_zone: "Europe/Warsaw"
    )

    assert workspace.valid?

    workspace.time_zone = "Mars/Olympus"

    assert_not workspace.valid?
    assert_includes(
      workspace.errors[:time_zone],
      "must be a valid IANA time zone"
    )
  end

  test "converts a submitted local time into its UTC instant" do
    workspace = create_workspace
    workspace.update!(time_zone: "Europe/Warsaw")

    instant = workspace.parse_local_datetime(
      "2026-08-03T10:30"
    )

    assert_equal(
      Time.utc(2026, 8, 3, 8, 30),
      instant
    )
    assert_equal(
      "2026-08-03T10:30",
      workspace.local_datetime_value(instant)
    )
  end

  test "rejects a local time skipped by daylight saving" do
    workspace = create_workspace
    workspace.update!(time_zone: "Europe/Warsaw")

    error = assert_raises(Workspace::InvalidLocalTime) do
      workspace.parse_local_datetime(
        "2026-03-29T02:30"
      )
    end

    assert_match(
      /does not exist in Europe\/Warsaw/,
      error.message
    )
  end

  test "rejects a local time repeated by daylight saving" do
    workspace = create_workspace
    workspace.update!(time_zone: "Europe/Warsaw")

    error = assert_raises(Workspace::InvalidLocalTime) do
      workspace.parse_local_datetime(
        "2026-10-25T02:30"
      )
    end

    assert_match(
      /occurs twice in Europe\/Warsaw/,
      error.message
    )
  end

  test "time zone options persist IANA identifiers" do
    option = Workspace.time_zone_options.find {
      |_label, identifier|
      identifier == "Europe/Warsaw"
    }

    assert option
    assert_equal "Europe/Warsaw", option.last
  end
end
