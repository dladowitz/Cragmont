class AddClassFieldsToTrips < ActiveRecord::Migration[8.0]
  def change
    add_reference :trips, :partner_company, foreign_key: true
    add_column :trips, :class_signup_url, :text
    add_column :trips, :class_original_price, :string
    add_column :trips, :class_discount_code, :string
    add_column :trips, :class_discount_amount, :string
    add_column :trips, :class_discounted_price, :string
  end
end
