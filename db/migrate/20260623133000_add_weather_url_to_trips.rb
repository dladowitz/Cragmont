class AddWeatherUrlToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :weather_url, :text
  end
end
