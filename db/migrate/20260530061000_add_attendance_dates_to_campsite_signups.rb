class AddAttendanceDatesToCampsiteSignups < ActiveRecord::Migration[8.1]
  def up
    add_column :campsite_signups, :arrival_date, :date
    add_column :campsite_signups, :checkout_date, :date

    execute <<~SQL.squish
      UPDATE campsite_signups
      SET arrival_date = campsites.arrival_date,
          checkout_date = campsites.checkout_date
      FROM campsites
      WHERE campsite_signups.campsite_id = campsites.id
    SQL

    change_column_null :campsite_signups, :arrival_date, false
    change_column_null :campsite_signups, :checkout_date, false

    add_index :campsite_signups, :arrival_date
    add_index :campsite_signups, :checkout_date
  end

  def down
    remove_index :campsite_signups, :checkout_date
    remove_index :campsite_signups, :arrival_date
    remove_column :campsite_signups, :checkout_date
    remove_column :campsite_signups, :arrival_date
  end
end
