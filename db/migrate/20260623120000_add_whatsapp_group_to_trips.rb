class AddWhatsappGroupToTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :trips, :whatsapp_group, :text
  end
end
