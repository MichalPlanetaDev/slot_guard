class RegistrationsController < ApplicationController
  layout "authentication"

  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 5,
    within: 10.minutes,
    only: :create,
    with: :redirect_after_rate_limit

  before_action :redirect_authenticated_user

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if create_account
      start_new_session_for @user

      redirect_to after_authentication_url,
        notice: "Your SlotGuard workspace is ready.",
        status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @user.errors.add(:email_address, "has already been taken")
    render :new, status: :unprocessable_entity
  end

  private

  def create_account
    User.transaction do
      return false unless @user.save

      workspace = Workspace.create!(
        name: "#{@user.name}'s workspace"
      )
      workspace.memberships.create!(
        user: @user,
        role: :owner
      )
    end

    true
  end

  def registration_params
    params.expect(
      user: %i[name email_address password password_confirmation]
    )
  end

  def redirect_authenticated_user
    redirect_to after_authentication_url if authenticated?
  end

  def redirect_after_rate_limit
    redirect_to new_registration_path,
      alert: "Too many registration attempts. Try again later."
  end
end
