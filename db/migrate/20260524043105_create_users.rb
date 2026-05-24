class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email
      t.string :phone
      t.boolean :member, null: false, default: false

      t.timestamps
    end

    add_index :users,
      "lower(email)",
      unique: true,
      name: "index_users_on_lower_email",
      where: "email IS NOT NULL AND email <> ''"
  end
end
