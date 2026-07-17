class PartnerCompanyPolicy < ApplicationPolicy
  def index?
    global_trip_admin?
  end

  def show?
    global_trip_admin?
  end

  def create?
    global_trip_admin?
  end

  def update?
    global_trip_admin?
  end

  def destroy?
    global_trip_admin?
  end
end
