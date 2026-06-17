class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: %i[show edit update destroy email_waiver_request]
  before_action :set_roles, only: %i[new edit create update]

  def index
    authorize User
    @users = User.order(:first_name, :last_name)
  end

  def show
    authorize @user
    @coordinated_trips = @user.coordinated_trips.order(start_date: :asc, name: :asc)
    @waivers = @user.waivers.includes(:trip, :waiver_minors, campsite_signup: [ :trip, :campsite, :campsite_signup_minors ]).with_attached_document.current_first
  end

  def new
    @user = User.new
    authorize @user
  end

  def edit
    authorize @user
  end

  def create
    @user = User.new(user_params)
    authorize @user

    if @user.save
      redirect_to admin_user_path(@user), notice: "User was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @user

    if @user.update(user_params_for_update)
      redirect_to admin_user_path(@user), notice: "User was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @user

    if @user.destroy
      redirect_to admin_users_path, notice: "User was deleted.", status: :see_other
    else
      redirect_to admin_user_path(@user),
        alert: "User cannot be deleted while assigned to trips.",
        status: :see_other
    end
  end

  def email_waiver_request
    authorize @user, :show?

    if @user.email.blank?
      message = "Wow, that was a whipper. #{@user.full_name} does not have an email address."
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), alert: message }
        format.json { render json: { message: message, button_text: "Email failed" }, status: :unprocessable_entity }
      end
    else
      WaiverRequestMailer.with(
        user: @user,
        requested_by: current_user,
        waiver_url: waiver_request_url(waiver_request_token(@user))
      ).sign_request.deliver_now
      message = "On belay! The waiver signing request was emailed to #{@user.full_name}."
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), notice: message }
        format.json { render json: { message: message, button_text: "Email sent" } }
      end
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_roles
    Role.seed_defaults!
    @roles = Role.order(:name)
  end

  def waiver_request_token(user)
    user.signed_id(purpose: :standalone_waiver_request)
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :phone, :member, :password, :password_confirmation, role_ids: [])
  end

  def user_params_for_update
    user_params.tap do |permitted_params|
      if permitted_params[:password].blank? && permitted_params[:password_confirmation].blank?
        permitted_params.delete(:password)
        permitted_params.delete(:password_confirmation)
      end
    end
  end
end
