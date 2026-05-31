class AddDefaultPasswordToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :default_password, :boolean, null: false, default: false
  end
end
