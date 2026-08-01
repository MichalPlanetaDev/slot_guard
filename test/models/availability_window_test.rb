require "test_helper"

class AvailabilityWindowTest < ActiveSupport::TestCase
  test "formats its weekly schedule" do
    window = AvailabilityWindow.new(
      weekday: 1,
      starts_minute: 9 * 60,
      ends_minute: 17 * 60
    )

    assert_equal "Monday", window.day_name
    assert_equal "09:00–17:00", window.time_range
  end

  test "rejects overlapping windows for one resource and weekday" do
    shared_resource = create_shared_resource(
      workspace: create_workspace
    )
    create_availability_window(
      shared_resource: shared_resource,
      weekday: 1,
      starts_minute: 9 * 60,
      ends_minute: 12 * 60
    )

    overlapping = AvailabilityWindow.new(
      shared_resource: shared_resource,
      weekday: 1,
      starts_minute: 11 * 60,
      ends_minute: 13 * 60
    )

    assert_not overlapping.valid?
    assert_includes(
      overlapping.errors[:base],
      "This availability window overlaps an existing window."
    )
  end

  test "the database rejects overlapping windows without validations" do
    shared_resource = create_shared_resource(
      workspace: create_workspace
    )
    create_availability_window(
      shared_resource: shared_resource,
      weekday: 2,
      starts_minute: 9 * 60,
      ends_minute: 12 * 60
    )

    overlapping = AvailabilityWindow.new(
      shared_resource: shared_resource,
      weekday: 2,
      starts_minute: 10 * 60,
      ends_minute: 11 * 60
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      AvailabilityWindow.transaction(requires_new: true) do
        overlapping.save!(validate: false)
      end
    end
  end

  test "allows adjacent windows" do
    shared_resource = create_shared_resource(
      workspace: create_workspace
    )
    create_availability_window(
      shared_resource: shared_resource,
      weekday: 3,
      starts_minute: 9 * 60,
      ends_minute: 12 * 60
    )

    adjacent = AvailabilityWindow.new(
      shared_resource: shared_resource,
      weekday: 3,
      starts_minute: 12 * 60,
      ends_minute: 15 * 60
    )

    assert adjacent.valid?
  end
end
