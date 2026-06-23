class Admin::TripReadinessController < Admin::BaseController
  before_action :set_trip

  def show
    authorize @trip, :show?
    @checklist = TripReadinessChecklist.new(@trip)
  end

  def update
    authorize @trip, :update?

    if @trip.deleted?
      respond_with_failure("Wow, that was a whipper. Restore this trip before changing readiness tasks.")
    elsif !TripReadinessChecklist.completable_task_key?(task_key, trip: @trip)
      respond_with_failure("Wow, that was a whipper. That readiness task cannot be changed.")
    elsif completed?
      completion = @trip.trip_readiness_completions.find_or_initialize_by(task_key: task_key)
      completion.assign_attributes(completed_at: Time.current, completed_by: current_user)
      completion.save!
      respond_with_success("On belay! Readiness task marked complete.")
    else
      @trip.trip_readiness_completions.where(task_key: task_key).destroy_all
      respond_with_success("On belay! Readiness task moved back onto the rack.")
    end
  end

  private

  def set_trip
    @trip = Trip.find(params[:id])
  end

  def task_key
    params[:task_key].to_s
  end

  def completed?
    ActiveModel::Type::Boolean.new.cast(params[:completed])
  end

  def respond_with_success(message)
    respond_to do |format|
      format.html { redirect_to readiness_admin_trip_path(@trip), notice: message, status: :see_other }
      format.json { render json: readiness_response_payload(message: message) }
    end
  end

  def respond_with_failure(message)
    respond_to do |format|
      format.html { redirect_to readiness_admin_trip_path(@trip), alert: message, status: :see_other }
      format.json { render json: { message: message }, status: :unprocessable_entity }
    end
  end

  def readiness_response_payload(message:)
    checklist = TripReadinessChecklist.new(@trip.reload)
    category = checklist.categories.find { |candidate| candidate.tasks.any? { |task| task.key == task_key } }
    task = category.tasks.find { |candidate| candidate.key == task_key }

    {
      message: message,
      task: {
        key: task.key,
        complete: task.complete?,
        completion_text: completion_text(task),
        completed_value: task.complete? ? "0" : "1",
        button_text: task.complete? ? "Mark incomplete" : "Mark Complete"
      },
      category: {
        key: category.key,
        count_text: "#{category.completed_count} of #{category.total_count}",
        complete: category.completed_count == category.total_count
      },
      total: {
        count_text: "#{checklist.completed_count} of #{checklist.total_count}",
        complete: checklist.completed_count == checklist.total_count
      }
    }
  end

  def completion_text(task)
    return if task.completion.blank?

    "Completed by #{task.completion.completed_by&.full_name || "Unknown"} on #{task.completion.completed_at.to_fs(:long)}"
  end
end
