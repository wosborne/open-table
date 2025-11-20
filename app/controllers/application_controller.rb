class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!

  def after_sign_in_path_for(resource)
    if resource.accounts.any?
      account_dashboard_path(resource.accounts.first)
    else
      new_account_path
    end
  end
end
