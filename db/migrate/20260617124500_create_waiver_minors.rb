class CreateWaiverMinors < ActiveRecord::Migration[8.1]
  def change
    create_table :waiver_minors do |t|
      t.references :waiver, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.integer :age, null: false
      t.string :relationship, null: false

      t.timestamps
    end

    add_index :waiver_minors, :age
  end
end
