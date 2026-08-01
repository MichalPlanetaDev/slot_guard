require "test_helper"

class WorkspaceSettingsControllerTest <
    ActionDispatch::IntegrationTest
  test "requires authentication" do
    get edit_workspace_settings_path

    assert_redirected_to new_session_path
  end

  test "an owner can update workspace identity and time zone" do
    workspace = create_workspace(name: "Old Lab")
    owner = create_user(workspace: workspace)

    sign_in_as owner

    patch workspace_settings_path, params: {
      workspace: {
        name: "Engineering Lab",
        time_zone: "Europe/Warsaw"
      }
    }

    assert_redirected_to edit_workspace_settings_path

    workspace.reload

    assert_equal "Engineering Lab", workspace.name
    assert_equal "Europe/Warsaw", workspace.time_zone
  end

  test "an invalid IANA identifier renders an error without previewing it" do
    workspace = create_workspace
    owner = create_user(workspace: workspace)

    sign_in_as owner

    patch workspace_settings_path, params: {
      workspace: {
        name: workspace.name,
        time_zone: "Mars/Olympus"
      }
    }

    assert_response :unprocessable_entity
    assert_select "[role='alert']",
      text: /must be a valid IANA time zone/
    assert_select "p",
      text: "Choose a valid time zone to preview the workspace clock."
    assert_equal "Etc/UTC", workspace.reload.time_zone
  end

  test "a manager cannot change workspace settings" do
    workspace = create_workspace
    create_user(workspace: workspace)
    manager = create_user(
      workspace: workspace,
      role: :manager
    )

    sign_in_as manager

    patch workspace_settings_path, params: {
      workspace: {
        name: "Unauthorized change",
        time_zone: "Europe/Warsaw"
      }
    }

    assert_redirected_to workspace_team_path
    assert_not_equal(
      "Unauthorized change",
      workspace.reload.name
    )
  end
end
