class CreateTripSignupMinors < ActiveRecord::Migration[8.1]
  def change
    create_table :trip_signup_minors do |t|
      t.references :trip_signup, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.integer :age, null: false
      t.string :relationship, null: false

      t.timestamps
    end

    add_index :trip_signup_minors, :age
  end
end
