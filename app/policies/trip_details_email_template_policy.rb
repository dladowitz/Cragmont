class TripDetailsEmailTemplatePolicy < ApplicationPolicy
  def index?
    super_admin?
  end

  def edit?
    super_admin?
  end

  def update?
    super_admin?
  end

  def preview?
    super_admin?
  end
end
