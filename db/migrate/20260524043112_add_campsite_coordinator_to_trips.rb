class AddCampsiteCoordinatorToTrips < ActiveRecord::Migration[8.1]
  def change
    add_reference :trips, :campsite_coordinator, null: true, foreign_key: { to_table: :users }
  end
end
