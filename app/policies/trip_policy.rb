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
    global_trip_admin? || finance_admin? || assigned_campsite_coordinator?
  end

  def assign_coordinator?
    global_trip_admin?
  end

  def permitted_attributes
    attributes = %i[name location start_date end_date description status whatsapp_group]
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
