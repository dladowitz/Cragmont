class AddDeletedAtToTrips < ActiveRecord::Migration[8.0]
  def change
    add_column :trips, :deleted_at, :datetime
    add_index :trips, :deleted_at
  end
end
