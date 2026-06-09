class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.none
    end

    private

    attr_reader :user, :scope
  end

  private

  def super_admin?
    user&.super_admin?
  end

  def finance_admin?
    user&.finance_admin?
  end

  def trip_admin?
    user&.trip_admin?
  end

  def assigned_campsite_coordinator?
    record.respond_to?(:campsite_coordinator_id) && record.campsite_coordinator_id == user&.id
  end

  def global_trip_admin?
    super_admin? || trip_admin?
  end

  def global_finance_admin?
    super_admin? || finance_admin?
  end
end
