class CreateResources < ActiveRecord::Migration[8.1]
  def change
    create_table :resources do |t|
      t.references :user, null: false, foreign_key: true
      t.string :category, null: false
      t.string :kind, null: false
      t.string :title, null: false
      t.string :url
      t.text :body
      t.timestamps
    end
    add_index :resources, %i[category created_at]
  end
end
