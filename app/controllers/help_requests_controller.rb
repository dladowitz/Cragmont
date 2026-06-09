class HelpRequestsController < ApplicationController
  before_action :log_in_with_help_request_access_token, only: :show
  before_action :require_login, only: %i[index show reply]
  before_action :set_help_request, only: %i[show reply]

  def index
    @help_requests = current_user.help_requests.includes(:replies).recent_first
  end

  def new
    @help_request = HelpRequest.new(prefilled_contact_attributes)
  end

  def create
    @help_request = HelpRequest.new(help_request_params)
    apply_signed_in_contact
    return render_missing_guest_contact if missing_guest_contact?

    guest_user_to_login = nil
    saved = false

    HelpRequest.transaction do
      guest_user_to_login = apply_guest_contact unless current_user
      saved = @help_request.save
      raise ActiveRecord::Rollback unless saved
    end

    if saved
      log_in_help_request_user(guest_user_to_login) if guest_user_to_login
      HelpRequestMailer.with(help_request: @help_request).admin_notification.deliver_now if HelpNotificationSubscriber.exists?
      HelpRequestMailer.with(help_request: @help_request).confirmation.deliver_now
      redirect_to after_create_path, notice: "On belay! Your message was sent to the Cragmont admins."
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def show
    @reply = HelpRequestReply.new
  end

  def reply
    @reply = @help_request.replies.build(reply_params.merge(user: current_user))

    if @reply.save
      @help_request.mark_open!
      HelpRequestMailer.with(reply: @reply).user_reply_notification.deliver_now if HelpNotificationSubscriber.exists?
      redirect_to help_request_path(@help_request), notice: "On belay! Your reply was sent."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def help_request_params
    params.require(:help_request).permit(:reason, :first_name, :last_name, :name, :email, :subject, :message, images: [])
  end

  def reply_params
    params.require(:help_request_reply).permit(:message, files: [])
  end

  def set_help_request
    @help_request = current_user.help_requests.includes(
      replies: [ :user, { files_attachments: :blob } ],
      images_attachments: :blob
    ).find(params[:id])
  end

  def prefilled_contact_attributes
    return {} unless current_user

    {
      name: current_user.full_name,
      email: current_user.email
    }
  end

  def apply_signed_in_contact
    return unless current_user

    @help_request.user = current_user
    @help_request.name = current_user.full_name
    @help_request.email = current_user.email if current_user.email.present?
  end

  def apply_guest_contact
    email = @help_request.email.to_s.strip.downcase
    user = User.find_by(email: email)
    created_user = false

    if user.blank?
      default_password = User.generate_default_password
      user = User.create!(
        first_name: @help_request.first_name.to_s.strip,
        last_name: @help_request.last_name.to_s.strip,
        email: email,
        member: false,
        password: default_password,
        password_confirmation: default_password,
        default_password: true
      )
      created_user = true
    end

    @help_request.user = user
    @help_request.name = user.full_name
    @help_request.email = user.email

    created_user ? user : nil
  rescue ActiveRecord::RecordInvalid => error
    error.record.errors.full_messages.each { |message| @help_request.errors.add(:base, "Account #{message}") } if error.record.is_a?(User)
    raise
  end

  def missing_guest_contact?
    return false if current_user

    @help_request.first_name.to_s.strip.blank? || @help_request.last_name.to_s.strip.blank?
  end

  def render_missing_guest_contact
    @help_request.valid?
    @help_request.errors.add(:first_name, "can't be blank") if @help_request.first_name.to_s.strip.blank?
    @help_request.errors.add(:last_name, "can't be blank") if @help_request.last_name.to_s.strip.blank?
    render :new, status: :unprocessable_entity
  end

  def log_in_help_request_user(user)
    session[:user_id] = user.id
    @current_user = user
  end

  def log_in_with_help_request_access_token
    return if user_signed_in? || params[:access].blank?

    help_request = HelpRequest.find_signed(params[:access], purpose: HelpRequest::ACCESS_TOKEN_PURPOSE)
    return if help_request.blank? || help_request.id.to_s != params[:id].to_s || help_request.user.blank?

    log_in_help_request_user(help_request.user)
  end

  def after_create_path
    return help_request_path(@help_request) if current_user && @help_request.user_id == current_user.id

    new_help_request_path
  end
end
