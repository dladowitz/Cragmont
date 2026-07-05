class ProfilesController < ApplicationController
  before_action :require_login

  def show
    @user = current_user
    @coordinated_trips = @user.coordinated_trips.order(start_date: :asc, name: :asc)
    @trip_history_rows = UserTripHistory.for_user(@user)
    @recent_help_requests = @user.help_requests.recent_first.limit(5)
    @current_waiver = @user.current_waiver_for_year(Date.current.year)
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(profile_params_for_update)
      redirect_to profile_path, notice: "Your profile was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if params[:confirmation_text] != "Delete Me"
      redirect_to profile_path, alert: "Type Delete Me to confirm account deletion.", status: :see_other
      return
    end

    current_user.destroy_account_with_history!
    reset_session
    redirect_to root_path, notice: "Your account was deleted.", status: :see_other
  rescue ActiveRecord::RecordNotDestroyed
    redirect_to profile_path, alert: "Your account could not be deleted.", status: :see_other
  end

  private

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :email, :phone, :password, :password_confirmation)
  end

  def profile_params_for_update
    profile_params.tap do |permitted_params|
      if permitted_params[:password].blank? && permitted_params[:password_confirmation].blank?
        permitted_params.delete(:password)
        permitted_params.delete(:password_confirmation)
      end
    end
  end
end
