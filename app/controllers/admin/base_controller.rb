class Admin::BaseController < ApplicationController
  before_action :require_admin_login
  before_action :require_admin_access

  private

  def require_admin_login
    return if user_signed_in?

    redirect_to new_session_path, alert: "Please log in to access admin pages."
  end

  def require_admin_access
    return if current_user&.admin_access?

    raise Pundit::NotAuthorizedError
  end
end
