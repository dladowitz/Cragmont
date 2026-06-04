class AddMinorExtraNightFeeToSiteSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :site_settings, :minor_extra_night_fee_cents, :integer, null: false, default: 0
  end
end
