require "test_helper"

class DemoResetTest < ActiveSupport::TestCase
  test "restores deterministic demo data idempotently" do
    first_workspace = Demo::Reset.call(force: true)
    second_workspace = Demo::Reset.call(force: true)

    assert_equal first_workspace.id, second_workspace.id
    assert_equal "SlotGuard Demo", second_workspace.name
    assert_equal "Europe/Warsaw", second_workspace.time_zone
    assert_equal 3, second_workspace.shared_resources.count
    assert_equal 21,
      AvailabilityWindow.where(
        shared_resource_id: second_workspace.shared_resources.ids
      ).count
    assert_equal 3, second_workspace.reservations.confirmed.count
    assert_equal 1, second_workspace.blackout_periods.count
    assert_equal 3, second_workspace.memberships.count

    owner = User.find_by!(
      email_address: Demo::Reset::OWNER_EMAIL
    )

    assert owner.authenticate(
      Demo::Reset::OWNER_PASSWORD
    )
    assert second_workspace.memberships.find_by!(
      user: owner
    ).owner?
  end

  test "refuses to reset outside demo mode by default" do
    error = assert_raises(Demo::Reset::Disabled) do
      Demo::Reset.call
    end

    assert_instance_of Demo::Reset::Disabled, error
  end
end
