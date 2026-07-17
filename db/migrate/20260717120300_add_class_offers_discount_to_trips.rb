class AddClassOffersDiscountToTrips < ActiveRecord::Migration[8.0]
  def change
    add_column :trips, :class_offers_discount, :boolean, null: false, default: false
  end
end
