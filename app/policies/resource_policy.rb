class ResourcePolicy < ApplicationPolicy
  # Admins publish immediately; members read.
  def create?
    global_trip_admin?
  end

  def update?
    user.present? && (record.user_id == user.id || global_trip_admin?)
  end

  def destroy?
    update?
  end
end
