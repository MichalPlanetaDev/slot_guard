require "test_helper"

class SharedResourceTest < ActiveSupport::TestCase
  test "normalizes descriptive fields" do
    workspace = create_workspace

    shared_resource = create_shared_resource(
      workspace: workspace,
      name: "  Camera   Kit  ",
      category: :equipment,
      location: "  Cabinet   4  ",
      description: "  Includes two batteries.  "
    )

    assert_equal "Camera Kit", shared_resource.name
    assert_equal "Cabinet 4", shared_resource.location
    assert_equal "Includes two batteries.", shared_resource.description
  end

  test "requires a supported category" do
    shared_resource = SharedResource.new(
      workspace: create_workspace,
      name: "Unclassified resource",
      category: "vehicle"
    )

    assert_not shared_resource.valid?
    assert_includes shared_resource.errors[:category], "is not included in the list"
  end

  test "requires a positive capacity when capacity is provided" do
    shared_resource = SharedResource.new(
      workspace: create_workspace,
      name: "Meeting room",
      category: :room,
      capacity: 0
    )

    assert_not shared_resource.valid?
    assert_includes shared_resource.errors[:capacity], "must be greater than 0"
  end

  test "keeps names unique within a workspace regardless of case" do
    workspace = create_workspace
    create_shared_resource(
      workspace: workspace,
      name: "Studio A"
    )

    duplicate = SharedResource.new(
      workspace: workspace,
      name: "studio a",
      category: :room
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "allows the same name in different workspaces" do
    create_shared_resource(
      workspace: create_workspace,
      name: "Studio A"
    )

    second = build_shared_resource(
      workspace: create_workspace,
      name: "Studio A"
    )

    assert second.valid?
  end

  private

  def build_shared_resource(workspace:, name:)
    SharedResource.new(
      workspace: workspace,
      name: name,
      category: :room
    )
  end
end
