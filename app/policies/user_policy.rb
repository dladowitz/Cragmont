class UserPolicy < ApplicationPolicy
  def index?
    super_admin?
  end

  def show?
    user&.admin_access?
  end

  def create?
    super_admin?
  end

  def update?
    super_admin?
  end

  def destroy?
    super_admin?
  end

  def assign_roles?
    super_admin?
  end
end
