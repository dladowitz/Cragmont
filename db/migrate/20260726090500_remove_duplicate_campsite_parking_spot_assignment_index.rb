class RemoveDuplicateCampsiteParkingSpotAssignmentIndex < ActiveRecord::Migration[8.1]
  def change
    remove_index :campsite_parking_spots, name: "index_campsite_parking_spots_on_assigned_campsite_signup_id", if_exists: true
  end
end
