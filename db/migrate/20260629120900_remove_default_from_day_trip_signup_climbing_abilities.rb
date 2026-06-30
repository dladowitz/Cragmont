class RemoveDefaultFromDayTripSignupClimbingAbilities < ActiveRecord::Migration[8.1]
  def change
    return unless column_exists?(:day_trip_signups, :climbing_abilities)

    change_column_default :day_trip_signups, :climbing_abilities, from: "top_rope", to: nil
    change_column_null :day_trip_signups, :climbing_abilities, true
  end
end
