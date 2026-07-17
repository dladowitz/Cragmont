class BackfillClassOffersDiscountOnTrips < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE trips
      SET class_offers_discount = TRUE
      WHERE trip_type = 'class_trip'
        AND (
          NULLIF(TRIM(class_discount_code), '') IS NOT NULL
          OR NULLIF(TRIM(class_discount_amount), '') IS NOT NULL
          OR NULLIF(TRIM(class_discounted_price), '') IS NOT NULL
        )
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE trips
      SET class_offers_discount = FALSE
      WHERE trip_type = 'class_trip'
    SQL
  end
end
