require "test_helper"

class TripPolicyTest < ActiveSupport::TestCase
  setup do
    @trip = trips(:jtree)
    @super_admin = users(:alex)
    @finance_admin = users(:sam)
    assign_role(@finance_admin, :finance_admin)
    @trip_admin = User.create!(first_name: "Tara", last_name: "Tripadmin", email: "tara-tripadmin@example.com", password: "password")
    assign_role(@trip_admin, :trip_admin)
    @coordinator = User.create!(first_name: "Casey", last_name: "Coordinator", email: "casey-trip-policy@example.com", password: "password")
    @trip.update!(campsite_coordinator: @coordinator)
    @participant = User.create!(first_name: "Pat", last_name: "Participant", email: "pat-trip-policy@example.com", password: "password")
  end

  test "super admin can do everything on trips" do
    policy = TripPolicy.new(@super_admin, @trip)

    assert policy.show?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
    assert policy.restore?
    assert policy.manage_campsites?
    assert policy.manage_participants?
    assert policy.manage_payments?
    assert policy.assign_coordinator?
  end

  test "trip admin can manage trips and payments" do
    policy = TripPolicy.new(@trip_admin, @trip)

    assert policy.show?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
    assert policy.manage_campsites?
    assert policy.manage_participants?
    assert policy.manage_payments?
    assert policy.assign_coordinator?
  end

  test "finance admin can access payment surfaces without editing trips" do
    policy = TripPolicy.new(@finance_admin, @trip)

    assert policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
    assert_not policy.manage_campsites?
    assert_not policy.manage_participants?
    assert policy.manage_payments?
    assert_not policy.assign_coordinator?
  end

  test "assigned coordinator can manage only assigned trip without assigning coordinators" do
    assigned_policy = TripPolicy.new(@coordinator, @trip)
    other_policy = TripPolicy.new(@coordinator, trips(:yosemite))

    assert assigned_policy.show?
    assert assigned_policy.update?
    assert assigned_policy.manage_campsites?
    assert assigned_policy.manage_participants?
    assert assigned_policy.manage_payments?
    assert_not assigned_policy.create?
    assert_not assigned_policy.destroy?
    assert_not assigned_policy.assign_coordinator?
    assert_not other_policy.show?
    assert_not other_policy.update?
  end

  test "participant cannot access trip admin policies" do
    policy = TripPolicy.new(@participant, @trip)

    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.manage_payments?
  end

  test "scope returns all trips for global admins and assigned trips for coordinators" do
    assert_includes TripPolicy::Scope.new(@super_admin, Trip).resolve, @trip
    assert_includes TripPolicy::Scope.new(@finance_admin, Trip).resolve, trips(:yosemite)
    assert_equal [ @trip ], TripPolicy::Scope.new(@coordinator, Trip).resolve.to_a
    assert_empty TripPolicy::Scope.new(@participant, Trip).resolve
  end
end
