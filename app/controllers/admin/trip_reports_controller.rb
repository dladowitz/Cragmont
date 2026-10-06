class Admin::TripReportsController < Admin::BaseController
  before_action :set_report, only: %i[show edit update publish hide cover_photo photo preview]
  before_action :private_response

  rescue_from ActiveRecord::StaleObjectError do
    report_error("Someone else changed this report. Your changes are still here; open the latest version in another tab before saving again.", :conflict)
  end
  rescue_from ActiveRecord::RecordInvalid do |error|
    report_error(error.record.errors.full_messages.join(". "), :unprocessable_entity)
  end
  rescue_from ActiveRecord::RecordNotUnique do
    report_error("This trip already has a report. Open it from Trip Reports instead.", :conflict)
  end
  rescue_from ArgumentError, ActionController::BadRequest do |error|
    report_error(error.message, :unprocessable_entity)
  end
  rescue_from ActionController::InvalidAuthenticityToken do
    report_error("Reload the editor to refresh your session before saving.", :unprocessable_entity)
  end

  def index
    authorize TripReport
    @reports = policy_scope(TripReport).includes(:trip).to_a
    trips = policy_scope(Trip).active.includes(:trip_report).order(start_date: :desc)
    trips.each do |trip|
      report = TripReport.for_trip(trip)
      @reports << report if report.new_record? && trip.automatic_report_eligible? && policy(report).update?
    end
    @reports.select! { |report| report.display_status.downcase.start_with?(params[:status]) } if params[:status].in?(%w[draft published hidden])
    if params[:q].present?
      raise ArgumentError, "q must be text" unless params[:q].is_a?(String)
      query = params[:q].downcase
      @reports.select! { |report| [ report.draft["title"], report.trip&.name ].compact.join(" ").downcase.include?(query) }
    end
    @reports.sort_by! { |report| report.draft["start_date"].to_s }.reverse!
    respond_to do |format|
      format.html
      format.json { render json: { reports: @reports.map { |report| report_json(report) } } }
    end
  end

  def new
    @report = build_report(params[:trip_id])
    authorize TripReport, :index?
    authorize @report, :create? if @report.trip || params[:standalone].present?
    return redirect_to edit_admin_trip_report_path(@report) if @report.persisted?
    set_trip_choices
  end

  def create
    @report = build_report(report_params[:trip_id])
    authorize @report, :create?
    if @report.persisted?
      return respond_to do |format|
        format.html { redirect_to edit_admin_trip_report_path(@report), notice: "This trip already has a report. Continue editing it here." }
        format.json { render json: { error: "Trip already has a report", edit_path: edit_admin_trip_report_path(@report) }, status: :conflict }
      end
    end
    @report.save_draft!(draft_attributes, version: 0, actor: current_user)
    @report.publish!(version: @report.lock_version, actor: current_user) if params[:intent] == "publish"
    saved_response(:created)
  end

  def show
    render json: { report: report_json(@report) }
  end

  def edit
    set_trip_choices
  end

  def update
    TripReport.transaction do
      if report_params.key?(:trip_id) && report_params[:trip_id].to_s != @report.trip_id.to_s
        authorize @report, :link_trip?
        @report.trip = Trip.find(Integer(report_params[:trip_id].to_s, 10)) if report_params[:trip_id].present?
        raise ArgumentError, "A linked report cannot be detached from its trip" if report_params[:trip_id].blank?
      end
      @report.save_draft!(draft_attributes, version: report_params[:lock_version], actor: current_user)
      @report.publish!(version: @report.lock_version, actor: current_user) if params[:intent] == "publish"
    end
    saved_response
  end

  def publish
    @report.publish!(version: params.require(:lock_version), actor: current_user)
    saved_response
  end

  def hide
    @report.hide!(version: params.require(:lock_version), actor: current_user)
    saved_response
  end

  def cover_photo
    upload = params.require(:photo)
    raise ArgumentError, "Choose one cover photo" unless upload.is_a?(ActionDispatch::Http::UploadedFile)
    @report.add_photos!([ upload ], version: params.require(:lock_version), actor: current_user)
    saved_response
  end

  def photo
    attachment = @report.photos.find(params[:photo_id])
    send_data attachment.variant(resize_to_limit: [ 1600, 1600 ], saver: { strip: true }).processed.download,
      type: attachment.content_type, disposition: "inline"
  end

  def preview
    render partial: "trip_reports/report", locals: { report: @report, payload: @report.draft, preview: true }
  end

  private

  def set_report
    @report = TripReport.find(params[:id])
    authorize @report, :update?
  end

  def private_response
    response.headers["Cache-Control"] = "private, no-store"
  end

  def build_report(trip_id)
    return TripReport.for_trip(Trip.find(Integer(trip_id.to_s, 10))) if trip_id.present?
    TripReport.new(draft: { "title" => "", "start_date" => TripCalendar::TIME_ZONE.today.to_s,
      "end_date" => TripCalendar::TIME_ZONE.today.to_s, "trip_type" => "camping", "photos" => [] })
  end

  def set_trip_choices
    @trips = policy_scope(Trip).active.order(start_date: :desc)
    @trips = @trips.where(campsite_coordinator: current_user) unless current_user.super_admin? || current_user.trip_admin?
  end

  def report_params
    @report_params ||= begin
      input = params.require(:trip_report)
      raise ArgumentError, "trip_report must be an object" unless input.is_a?(ActionController::Parameters)
      unknown = input.keys - TripReport::FIELDS - %w[trip_id lock_version]
      raise ArgumentError, "Unsupported report fields: #{unknown.join(', ')}" if unknown.any?
      %w[trip_id lock_version].each do |field|
        raise ArgumentError, "#{field} must be an integer" unless input[field].nil? || input[field].is_a?(Integer) || input[field].is_a?(String)
      end
      TripReport::FIELDS.excluding("photos").each do |field|
        raise ArgumentError, "#{field} must be text" unless input[field].nil? || input[field].is_a?(String)
      end
      if input.key?(:photos)
        unless input[:photos].is_a?(Array) && input[:photos].all? { |photo| photo.is_a?(ActionController::Parameters) && (photo.keys - %w[id caption]).empty? }
          raise ArgumentError, "photos must be a list of photo IDs and captions"
        end
      end
      input.permit(:trip_id, :lock_version, *TripReport::FIELDS.excluding("photos"), photos: [ :id, :caption ])
    end
  end

  def draft_attributes
    attributes = report_params.except(:trip_id, :lock_version).to_h
    attributes["photos"] ||= [] if params[:trip_report].key?(:photos)
    attributes
  end

  def saved_response(status = :ok)
    respond_to do |format|
      format.html do
        if action_name == "publish" || params[:intent] == "publish"
          redirect_to trip_report_path(@report), notice: "On belay! Your trip report is published."
        else
          redirect_to edit_admin_trip_report_path(@report), notice: "On belay! Your trip report is saved."
        end
      end
      format.json do
        render json: { report: report_json(@report),
          preview_html: render_to_string(partial: "trip_reports/report", formats: [ :html ], locals: { report: @report, payload: @report.draft, preview: true }),
          photos_html: render_to_string(partial: "photos", formats: [ :html ], locals: { report: @report }) }, status: status
      end
    end
  end

  def report_json(report)
    { id: report.id, trip_id: report.trip_id, lock_version: report.lock_version, draft: report.draft,
      status: report.display_status, published_at: report.published_at, hidden: report.hidden?,
      public_path: report.public_payload && report.persisted? ? trip_report_path(report) : nil,
      updated_at: report.updated_at, edit_path: report.persisted? ? edit_admin_trip_report_path(report) : new_admin_trip_report_path(trip_id: report.trip_id) }
  end

  def report_error(message, status)
    respond_to do |format|
      format.json { render json: { error: message }, status: status }
      format.html do
        return render plain: message, status: status unless @report
        flash.now[:alert] = message
        set_trip_choices
        render(@report&.persisted? ? :edit : :new, status: status)
      end
    end
  end
end
