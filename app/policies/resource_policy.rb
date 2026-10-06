class ResourcePolicy < ApplicationPolicy
  # Any signed-in account publishes immediately; the club asked for no review queue to start.
  def create?
    user.present?
  end

  def update?
    user.present? && (record.user_id == user.id || global_trip_admin?)
  end

  def destroy?
    update?
  end
end
