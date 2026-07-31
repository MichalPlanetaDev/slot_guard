require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  test "normalizes its name" do
    workspace = create_workspace(
      name: "  North   Workshop  "
    )

    assert_equal "North Workshop", workspace.name
  end

  test "requires a meaningful name" do
    workspace = Workspace.new(name: " ")

    assert_not workspace.valid?
    assert_includes workspace.errors[:name], "can't be blank"
  end
end
