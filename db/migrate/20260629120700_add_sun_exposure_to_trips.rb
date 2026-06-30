class AddSunExposureToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :sun_exposure, :string unless column_exists?(:trips, :sun_exposure)
  end
end
