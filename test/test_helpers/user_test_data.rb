require "securerandom"

module UserTestData
  TEST_PASSWORD = "test-password-123"

  def create_workspace(name: nil)
    Workspace.create!(
      name: name || "Workspace #{SecureRandom.hex(5)}"
    )
  end

  def create_user(
    name: "Ada Lovelace",
    email_address: nil,
    password: TEST_PASSWORD,
    workspace: :personal,
    role: :owner
  )
    user = User.create!(
      name: name,
      email_address: email_address ||
        "user-#{SecureRandom.hex(8)}@example.com",
      password: password,
      password_confirmation: password
    )

    selected_workspace = if workspace == :personal
      create_workspace(name: "#{user.name}'s workspace")
    else
      workspace
    end

    if selected_workspace
      Membership.create!(
        workspace: selected_workspace,
        user: user,
        role: role
      )
    end

    user
  end

  def create_shared_resource(
    workspace:,
    name: nil,
    category: :room,
    **attributes
  )
    SharedResource.create!(
      {
        workspace: workspace,
        name: name || "Resource #{SecureRandom.hex(5)}",
        category: category
      }.merge(attributes)
    )
  end
end
