class ContentPagePolicy < ApplicationPolicy
  def index?
    super_admin? || trip_admin?
  end

  def edit?
    super_admin? || class_reminder_for_trip_admin?
  end

  def update?
    edit?
  end

  def preview?
    super_admin? || trip_admin?
  end

  private

  def class_reminder_for_trip_admin?
    trip_admin? && record.respond_to?(:slug) && record.slug == "class_reminder"
  end
end
