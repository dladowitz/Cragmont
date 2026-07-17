class CreatePartnerCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :partner_companies do |t|
      t.string :name, null: false
      t.text :website_url, null: false
      t.string :primary_contact_name, null: false
      t.string :primary_contact_phone, null: false
      t.string :primary_contact_email, null: false
      t.string :secondary_contact_name
      t.string :secondary_contact_phone
      t.string :secondary_contact_email
      t.text :description

      t.timestamps
    end

    add_index :partner_companies, :name
  end
end
