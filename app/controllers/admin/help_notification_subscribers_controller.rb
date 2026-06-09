class Admin::HelpNotificationSubscribersController < Admin::BaseController
  before_action :require_super_admin
  before_action :set_subscriber, only: :destroy

  def index
    @subscriber = HelpNotificationSubscriber.new
    @subscribers = HelpNotificationSubscriber.alphabetical
  end

  def create
    @subscriber = HelpNotificationSubscriber.new(subscriber_params)

    if @subscriber.save
      redirect_to admin_help_notification_subscribers_path, notice: "On belay! Help notification email added."
    else
      @subscribers = HelpNotificationSubscriber.alphabetical
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @subscriber.destroy
    redirect_to admin_help_notification_subscribers_path, notice: "Off belay. Help notification email removed.", status: :see_other
  end

  private

  def require_super_admin
    return if current_user&.super_admin?

    raise Pundit::NotAuthorizedError
  end

  def set_subscriber
    @subscriber = HelpNotificationSubscriber.find(params[:id])
  end

  def subscriber_params
    params.require(:help_notification_subscriber).permit(:email)
  end
end
