class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern
  stale_when_importmap_changes

  private

  def after_authentication_url
    dashboard_path
  end
end
