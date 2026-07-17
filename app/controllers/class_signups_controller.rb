class ClassSignupsController < ApplicationController
  before_action :require_login
  before_action :set_trip

  def create
    signup = @trip.class_signups.active.find_or_initialize_by(user: current_user)

    if signup.persisted?
      redirect_to trip_path(@trip), alert: "Wow, that was a whipper. You're already marked as interested in this class."
    elsif !@trip.available_for_class_signup?
      redirect_to trip_path(@trip), alert: "Wow, that was a whipper. This class is full."
    elsif signup.save
      redirect_to trip_path(@trip), notice: "On belay! You're marked as planning to register for this class."
    else
      redirect_to trip_path(@trip), alert: signup.errors.full_messages.to_sentence
    end
  end

  def destroy
    signup = @trip.class_signups.active.find_by(user: current_user)

    if signup.blank?
      redirect_to trip_path(@trip), alert: "You're not marked as interested in this class.", status: :see_other
    else
      signup.update!(status: "canceled")
      redirect_to trip_path(@trip), notice: "You're off the class roster. We'll catch you on the next pitch.", status: :see_other
    end
  end

  private

  def set_trip
    @trip = Trip.published_for_public.class_trip.find(params[:trip_id])
  end
end
