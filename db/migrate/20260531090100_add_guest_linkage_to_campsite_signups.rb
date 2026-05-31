class AddGuestLinkageToCampsiteSignups < ActiveRecord::Migration[8.1]
  def change
    add_reference :campsite_signups,
      :guest_of_signup,
      foreign_key: { to_table: :campsite_signups },
      index: true

    add_column :campsite_signups, :guest_position, :integer
    add_index :campsite_signups,
      [ :guest_of_signup_id, :guest_position ],
      name: "index_campsite_signups_on_guest_signup_position",
      where: "guest_of_signup_id IS NOT NULL"
  end
end
