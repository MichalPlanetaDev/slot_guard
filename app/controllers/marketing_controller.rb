class MarketingController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    redirect_to dashboard_path if authenticated?
  end
end
