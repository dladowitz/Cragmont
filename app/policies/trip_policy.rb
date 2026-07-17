class TripPolicy < ApplicationPolicy
  def index?
    user&.admin_access?
  end

  def show?
    global_trip_admin? || finance_admin? || assigned_campsite_coordinator?
  end

  def create?
    global_trip_admin?
  end

  def update?
    global_trip_admin? || assigned_campsite_coordinator?
  end

  def destroy?
    global_trip_admin?
  end

  def restore?
    destroy?
  end

  def manage_campsites?
    update?
  end

  def manage_participants?
    update?
  end

  def manage_payments?
    return false if record.respond_to?(:camping?) && !record.camping?

    global_trip_admin? || finance_admin? || assigned_campsite_coordinator?
  end

  def manage_trip_details_email?
    update?
  end

  def view_trip_details_email?
    show?
  end

  def assign_coordinator?
    global_trip_admin?
  end

  def permitted_attributes
    attributes = %i[
      name location start_date end_date description status trip_type whatsapp_group weather_url photo_album_url
      group_campfire_campsite_id group_fire_night meeting_time meeting_location meeting_location_url
      late_arrival_instructions carpool_meeting_spot end_time cost_cents cost_dollars participant_capacity
      sun_exposure mountain_project_url guide_book_url day_trip_image partner_company_id class_signup_url
      class_original_price class_offers_discount class_discount_code class_discount_amount class_discounted_price
    ]
    attributes << { climbing_types: [] }
    attributes << :campsite_coordinator_id if global_trip_admin?
    attributes
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.super_admin? || user&.trip_admin? || user&.finance_admin?
      return scope.where(campsite_coordinator: user) if user.present?

      scope.none
    end
  end
end
