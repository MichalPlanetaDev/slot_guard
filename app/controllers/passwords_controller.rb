class PasswordsController < ApplicationController
  layout "authentication"

  allow_unauthenticated_access
  rate_limit to: 5,
    within: 15.minutes,
    only: :create,
    with: :redirect_after_rate_limit

  before_action :set_user_by_token, only: %i[edit update]

  def new
  end

  def create
    email_address = params[:email_address].to_s.strip.downcase

    if (user = User.find_by(email_address: email_address))
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path,
      notice: "Reset instructions were sent if that account exists.",
      status: :see_other
  end

  def edit
  end

  def update
    if @user.update(password_params)
      @user.sessions.delete_all

      redirect_to new_session_path,
        notice: "Your password has been reset. Sign in again.",
        status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.permit(:password, :password_confirmation)
  end

  def set_user_by_token
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_path,
      alert: "That password reset link is invalid or has expired.",
      status: :see_other
  end

  def redirect_after_rate_limit
    redirect_to new_password_path,
      alert: "Too many reset requests. Try again later."
  end
end
