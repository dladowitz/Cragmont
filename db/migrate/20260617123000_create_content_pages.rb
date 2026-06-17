class CreateContentPages < ActiveRecord::Migration[8.0]
  def change
    create_table :content_pages do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.string :subtitle
      t.text :body, null: false

      t.timestamps
    end

    add_index :content_pages, :slug, unique: true
  end
end
