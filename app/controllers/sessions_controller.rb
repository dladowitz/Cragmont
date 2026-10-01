class SessionsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to login_return_path, notice: "You are logged in."
    else
      flash.now[:alert] = "Email or password is incorrect."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "You are logged out.", status: :see_other
  end

  private

  def login_return_path
    path = params[:return_to].to_s
    uri = URI.parse(path)
    return path if uri.relative? && uri.path.to_s.start_with?("/") && !path.start_with?("//")

    trips_path
  rescue URI::InvalidURIError
    trips_path
  end
end
