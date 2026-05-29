class CreateSiteSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :site_settings do |t|
      t.integer :uncounted_minor_age_limit, null: false, default: 13
      t.integer :campsite_weekend_fee_cents, null: false, default: 0
      t.integer :campsite_extra_night_fee_cents, null: false, default: 0
      t.integer :minor_fee_cents, null: false, default: 0

      t.timestamps
    end
  end
end
