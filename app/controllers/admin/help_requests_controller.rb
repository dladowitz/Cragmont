class Admin::HelpRequestsController < Admin::BaseController
  HELP_REQUESTS_PER_PAGE = 20

  before_action :set_help_request, only: %i[show reply resolve]

  def index
    @selected_statuses = selected_statuses
    help_requests_scope = HelpRequest.includes(:user).where(status: @selected_statuses).recent_first

    @current_page = [ params[:page].to_i, 1 ].max
    @total_help_requests = help_requests_scope.count
    @total_pages = (@total_help_requests.to_f / HELP_REQUESTS_PER_PAGE).ceil
    @total_pages = 1 if @total_pages.zero?
    @current_page = @total_pages if @current_page > @total_pages

    @help_requests = help_requests_scope
      .offset((@current_page - 1) * HELP_REQUESTS_PER_PAGE)
      .limit(HELP_REQUESTS_PER_PAGE)
  end

  def show
    @reply = HelpRequestReply.new
  end

  def reply
    @reply = @help_request.replies.build(reply_params.merge(user: current_user))

    if @reply.save
      @help_request.mark_replied!
      HelpRequestMailer.with(reply: @reply).reply.deliver_now
      redirect_to admin_help_request_path(@help_request), notice: "On belay! Reply sent."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def resolve
    @help_request.mark_resolved!
    redirect_to admin_help_request_path(@help_request), notice: "On belay! Help request marked resolved.", status: :see_other
  end

  private

  def set_help_request
    @help_request = HelpRequest.includes(
      :user,
      replies: [ :user, { files_attachments: :blob } ],
      images_attachments: :blob
    ).find(params[:id])
  end

  def reply_params
    params.require(:help_request_reply).permit(:message, files: [])
  end

  def selected_statuses
    statuses = Array(params[:status]).select { |status| status.in?(HelpRequest::STATUSES) }
    statuses.presence || HelpRequest::STATUSES
  end
end
