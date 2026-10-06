class CreateAlbumCovers < ActiveRecord::Migration[8.1]
  def change
    create_table :album_covers do |t|
      t.string :album_url, null: false, index: { unique: true }
      t.string :source_url
      t.timestamps
    end
  end
end
