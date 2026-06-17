class ContentPagePolicy < ApplicationPolicy
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
