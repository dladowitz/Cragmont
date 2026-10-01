class CascadeCampsiteParkingSpotsOnCampsiteDelete < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :campsite_parking_spots, :campsites
    add_foreign_key :campsite_parking_spots, :campsites, on_delete: :cascade
  end
end
