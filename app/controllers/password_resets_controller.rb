class PasswordResetsController < ApplicationController
  before_action :set_user_from_token, only: %i[edit update]

  def new
  end

  def create
    user = User.find_by(email: reset_email) if reset_email.present?

    if user.blank?
      flash.now[:alert] = "That email isn't tied into Cragmont yet. Check the address or create an account."
      render :new, status: :unprocessable_entity
      return
    end

    token = user.generate_password_reset_token!
    PasswordResetMailer.with(
      user: user,
      token: token,
      request_host: request.host,
      request_protocol: request.protocol
    ).reset.deliver_now

    redirect_to new_session_path, notice: "We found your email in our system. A password reset link is being sent"
  end

  def edit
  end

  def update
    if password_params_valid? && @user.update(password_reset_params)
      redirect_to new_session_path, notice: "On belay! Your password has been reset."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def reset_email
    params[:email].to_s.strip.downcase.presence
  end

  def password_reset_params
    params.fetch(:user, {}).permit(:password, :password_confirmation)
  end

  def password_params_valid?
    permitted_params = password_reset_params

    if permitted_params[:password].blank?
      @user.errors.add(:password, "can't be blank")
    end

    if permitted_params[:password_confirmation].blank?
      @user.errors.add(:password_confirmation, "can't be blank")
    elsif permitted_params[:password] != permitted_params[:password_confirmation]
      @user.errors.add(:password_confirmation, "doesn't match Password")
    end

    @user.errors.blank?
  end

  def set_user_from_token
    @token = params[:token].to_s
    @user = User.find_by_password_reset_token(@token)

    return if @user.present?

    redirect_to new_password_reset_path, alert: "That reset link took a whipper. Please request a new one."
  end
end
