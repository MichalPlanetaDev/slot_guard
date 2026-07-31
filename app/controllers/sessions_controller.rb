class SessionsController < ApplicationController
  layout "authentication"

  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10,
    within: 3.minutes,
    only: :create,
    with: :redirect_after_rate_limit

  before_action :redirect_authenticated_user, only: %i[new create]

  def new
  end

  def create
    credentials = params.expect(session: %i[email_address password])
    email_address = credentials[:email_address].to_s.strip.downcase

    if (user = User.authenticate_by(
      email_address: email_address,
      password: credentials[:password]
    ))
      start_new_session_for user
      redirect_to after_authentication_url, status: :see_other
    else
      redirect_to new_session_path,
        alert: "The email address or password is incorrect.",
        status: :see_other
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other
  end

  private

  def redirect_authenticated_user
    redirect_to dashboard_path if authenticated?
  end

  def redirect_after_rate_limit
    redirect_to new_session_path,
      alert: "Too many sign-in attempts. Try again later."
  end
end
