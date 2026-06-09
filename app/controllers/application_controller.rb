class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :user_signed_in?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def current_user
    return nil if session[:user_id].blank?

    @current_user ||= User.find_by(id: session[:user_id])
  end

  def user_signed_in?
    current_user.present?
  end

  def require_login
    return if user_signed_in?

    redirect_to new_session_path, alert: "Please log in to sign up for trips."
  end

  def user_not_authorized
    redirect_back fallback_location: root_path,
      alert: "Wow, that was a whipper. You do not have permission to access that page."
  end
end
