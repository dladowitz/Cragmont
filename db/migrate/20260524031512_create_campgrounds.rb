class CreateCampgrounds < ActiveRecord::Migration[8.1]
  def change
    create_table :campgrounds do |t|
      t.string :name, null: false
      t.string :location, null: false
      t.string :website
      t.text :notes

      t.timestamps
    end

    add_index :campgrounds, :name
  end
end
