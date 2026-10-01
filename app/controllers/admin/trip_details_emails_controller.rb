class Admin::TripDetailsEmailsController < Admin::BaseController
  before_action :set_trip
  before_action :ensure_camping_trip
  before_action :set_trip_details_email, except: %i[new create]
  before_action :ensure_trip_not_deleted, except: :show

  def show
    if @trip_details_email.blank?
      authorize @trip, :manage_trip_details_email?
      redirect_to new_admin_trip_trip_details_email_path(@trip)
    elsif @trip_details_email.sent?
      authorize @trip, :view_trip_details_email?
      @recipients = @trip_details_email.trip_details_email_recipients.order(:recipient_name)
    else
      authorize @trip, :manage_trip_details_email?
      redirect_to edit_admin_trip_trip_details_email_path(@trip)
    end
  end

  def new
    authorize @trip, :manage_trip_details_email?

    if @trip.trip_details_email.present?
      redirect_to admin_trip_trip_details_email_path(@trip)
      return
    end

    @templates = active_templates
  end

  def create
    authorize @trip, :manage_trip_details_email?

    if @trip.trip_details_email.present?
      redirect_to admin_trip_trip_details_email_path(@trip), alert: "Wow, that was a whipper. This trip already has a details email."
      return
    end

    template = active_templates.find(params[:trip_details_email_template_id])
    @trip_details_email = template.build_trip_details_email(@trip)

    if @trip_details_email.save
      redirect_to edit_admin_trip_trip_details_email_path(@trip), notice: "On belay! Trip details email draft is ready."
    else
      @templates = active_templates
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @trip, :manage_trip_details_email?
    if @trip_details_email.sent?
      redirect_to admin_trip_trip_details_email_path(@trip)
      return
    end

    set_preview_context
  end

  def update
    authorize @trip, :manage_trip_details_email?
    if @trip_details_email.sent?
      redirect_to admin_trip_trip_details_email_path(@trip), alert: "That email has already left the anchor."
      return
    end

    if @trip_details_email.update(trip_details_email_params)
      redirect_to edit_admin_trip_trip_details_email_path(@trip), notice: "On belay! Draft saved."
    else
      set_preview_context
      render :edit, status: :unprocessable_entity
    end
  end

  def preview
    authorize @trip, :manage_trip_details_email?
    if @trip_details_email.sent?
      redirect_to admin_trip_trip_details_email_path(@trip), alert: "That email has already left the anchor."
      return
    end

    if request.patch?
      if @trip_details_email.update(trip_details_email_params)
        redirect_to preview_admin_trip_trip_details_email_path(@trip), notice: "On belay! Draft saved. Preview is ready."
      else
        set_preview_context
        render :edit, status: :unprocessable_entity
      end
    else
      set_preview_context
    end
  end

  def markdown_preview
    authorize @trip, :manage_trip_details_email?
    renderer = TripDetailsEmailRenderer.new(
      trip: @trip,
      subject: @trip_details_email&.subject,
      body_markdown: params[:body]
    )

    render html: renderer.rendered_html.html_safe
  end

  def reset_from_template
    authorize @trip, :manage_trip_details_email?
    if @trip_details_email.sent?
      redirect_to admin_trip_trip_details_email_path(@trip), alert: "That email has already left the anchor."
      return
    end

    template = @trip_details_email.trip_details_email_template
    if @trip_details_email.update(subject: template.subject_template, body_markdown: template.body_markdown)
      redirect_to edit_admin_trip_trip_details_email_path(@trip), notice: "On belay! Draft reset from the #{template.name} template."
    else
      set_preview_context
      render :edit, status: :unprocessable_entity
    end
  end

  def deliver
    authorize @trip, :manage_trip_details_email?
    if @trip_details_email.sent?
      redirect_to admin_trip_trip_details_email_path(@trip), alert: "That email has already left the anchor."
      return
    end

    TripDetailsEmailDelivery.deliver!(trip_details_email: @trip_details_email, sent_by: current_user)

    if @trip_details_email.failed_recipients_count.positive?
      redirect_to admin_trip_trip_details_email_path(@trip),
        alert: "The email was sent, but #{@trip_details_email.failed_recipients_count} #{'participant'.pluralize(@trip_details_email.failed_recipients_count)} took a whipper."
    else
      redirect_to admin_trip_trip_details_email_path(@trip), notice: "On belay! Trip details email was sent to #{@trip_details_email.delivered_recipients_count} #{'participant'.pluralize(@trip_details_email.delivered_recipients_count)}."
    end
  rescue TripDetailsEmailDelivery::BlockingIssuesError => error
    set_preview_context(blocking_issues: error.issues)
    render :preview, status: :unprocessable_entity
  rescue TripDetailsEmailDelivery::AlreadySentError
    redirect_to admin_trip_trip_details_email_path(@trip), alert: "That email has already left the anchor."
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def ensure_camping_trip
    return if @trip.camping?

    redirect_to admin_trip_path(@trip),
      alert: "Trip details email is only available for camping trips.",
      status: :see_other
  end

  def set_trip_details_email
    @trip_details_email = @trip.trip_details_email
    return if @trip_details_email.present? || action_name == "show"

    redirect_to new_admin_trip_trip_details_email_path(@trip), alert: "Start with a template before editing the trip details email."
  end

  def ensure_trip_not_deleted
    return unless @trip.deleted?

    redirect_to admin_trip_path(@trip), alert: "Restore this trip before changing the trip details email.", status: :see_other
  end

  def active_templates
    TripDetailsEmailTemplate.ensure_defaults!
    TripDetailsEmailTemplate.active.order(:name)
  end

  def trip_details_email_params
    params.require(:trip_details_email).permit(:subject, :body_markdown)
  end

  def set_preview_context(blocking_issues: nil)
    @renderer = TripDetailsEmailRenderer.new(
      trip: @trip,
      subject: @trip_details_email.subject,
      body_markdown: @trip_details_email.body_markdown
    )
    @rendered_subject = @renderer.rendered_subject
    @rendered_html = @renderer.rendered_html
    @readiness = TripDetailsEmailReadiness.new(@trip_details_email)
    @recipients = @readiness.recipients
    @blocking_issues = blocking_issues || @readiness.blocking_issues
  end
end
