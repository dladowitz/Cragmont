class TripReportPolicy < ApplicationPolicy
  def index?
    global_trip_admin? || user&.coordinated_trips&.exists?
  end

  def create?
    update?
  end

  def show?
    update?
  end

  def update?
    global_trip_admin? || (user.present? && record.trip.present? && record.trip.campsite_coordinator_id == user.id && !record.trip.deleted?)
  end

  def link_trip?
    global_trip_admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.super_admin? || user&.trip_admin?
      return scope.joins(:trip).where(trips: { campsite_coordinator_id: user.id, deleted_at: nil }) if user.present?
      scope.none
    end
  end
end
