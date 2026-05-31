# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_31_090100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "campgrounds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "location", null: false
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["name"], name: "index_campgrounds_on_name"
  end

  create_table "campsite_signup_minors", force: :cascade do |t|
    t.integer "age", null: false
    t.bigint "campsite_signup_id", null: false
    t.datetime "created_at", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "relationship", null: false
    t.datetime "updated_at", null: false
    t.index ["age"], name: "index_campsite_signup_minors_on_age"
    t.index ["campsite_signup_id"], name: "index_campsite_signup_minors_on_campsite_signup_id"
  end

  create_table "campsite_signups", force: :cascade do |t|
    t.date "arrival_date"
    t.bigint "campsite_id"
    t.date "checkout_date"
    t.datetime "created_at", null: false
    t.bigint "guest_of_signup_id"
    t.integer "guest_position"
    t.string "status", default: "confirmed", null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.datetime "waitlist_eligible_at"
    t.datetime "waiver_acknowledged_at"
    t.text "waiver_acknowledgement_text"
    t.string "waiver_acknowledgement_text_digest"
    t.string "waiver_ip_address"
    t.string "waiver_signature_digest"
    t.datetime "waiver_signed_at"
    t.string "waiver_signer_name"
    t.text "waiver_text"
    t.string "waiver_text_digest"
    t.string "waiver_user_agent"
    t.index ["arrival_date"], name: "index_campsite_signups_on_arrival_date"
    t.index ["campsite_id"], name: "index_campsite_signups_on_campsite_id"
    t.index ["checkout_date"], name: "index_campsite_signups_on_checkout_date"
    t.index ["guest_of_signup_id", "guest_position"], name: "index_campsite_signups_on_guest_signup_position", where: "(guest_of_signup_id IS NOT NULL)"
    t.index ["guest_of_signup_id"], name: "index_campsite_signups_on_guest_of_signup_id"
    t.index ["status"], name: "index_campsite_signups_on_status"
    t.index ["trip_id", "user_id"], name: "index_campsite_signups_on_trip_id_and_user_id", unique: true
    t.index ["trip_id"], name: "index_campsite_signups_on_trip_id"
    t.index ["user_id"], name: "index_campsite_signups_on_user_id"
    t.index ["waitlist_eligible_at"], name: "index_campsite_signups_on_waitlist_eligible_at"
    t.index ["waiver_acknowledged_at"], name: "index_campsite_signups_on_waiver_acknowledged_at"
    t.index ["waiver_acknowledgement_text_digest"], name: "index_campsite_signups_on_waiver_acknowledgement_text_digest"
    t.index ["waiver_signature_digest"], name: "index_campsite_signups_on_waiver_signature_digest"
    t.index ["waiver_signed_at"], name: "index_campsite_signups_on_waiver_signed_at"
    t.index ["waiver_text_digest"], name: "index_campsite_signups_on_waiver_text_digest"
  end

  create_table "campsites", force: :cascade do |t|
    t.date "arrival_date", null: false
    t.bigint "campground_id", null: false
    t.integer "car_capacity", null: false
    t.date "checkout_date", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.integer "participant_capacity", null: false
    t.bigint "registered_by_id"
    t.string "registration_number"
    t.datetime "signups_locked_at"
    t.string "site_number", null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["arrival_date"], name: "index_campsites_on_arrival_date"
    t.index ["campground_id"], name: "index_campsites_on_campground_id"
    t.index ["registered_by_id"], name: "index_campsites_on_registered_by_id"
    t.index ["signups_locked_at"], name: "index_campsites_on_signups_locked_at"
    t.index ["trip_id"], name: "index_campsites_on_trip_id"
  end

  create_table "site_settings", force: :cascade do |t|
    t.integer "campsite_extra_night_fee_cents", default: 0, null: false
    t.integer "campsite_weekend_fee_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "minor_fee_cents", default: 0, null: false
    t.integer "uncounted_minor_age_limit", default: 13, null: false
    t.datetime "updated_at", null: false
  end

  create_table "trip_signup_minors", force: :cascade do |t|
    t.integer "age", null: false
    t.datetime "created_at", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "relationship", null: false
    t.bigint "trip_signup_id", null: false
    t.datetime "updated_at", null: false
    t.index ["age"], name: "index_trip_signup_minors_on_age"
    t.index ["trip_signup_id"], name: "index_trip_signup_minors_on_trip_signup_id"
  end

  create_table "trip_signups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "status", default: "confirmed", null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.datetime "waiver_acknowledged_at"
    t.text "waiver_acknowledgement_text"
    t.string "waiver_acknowledgement_text_digest"
    t.string "waiver_ip_address"
    t.string "waiver_signature_digest"
    t.datetime "waiver_signed_at"
    t.string "waiver_signer_name"
    t.text "waiver_text"
    t.string "waiver_text_digest"
    t.string "waiver_user_agent"
    t.index ["status"], name: "index_trip_signups_on_status"
    t.index ["trip_id", "user_id"], name: "index_trip_signups_on_trip_id_and_user_id", unique: true
    t.index ["trip_id"], name: "index_trip_signups_on_trip_id"
    t.index ["user_id"], name: "index_trip_signups_on_user_id"
    t.index ["waiver_acknowledged_at"], name: "index_trip_signups_on_waiver_acknowledged_at"
    t.index ["waiver_acknowledgement_text_digest"], name: "index_trip_signups_on_waiver_acknowledgement_text_digest"
    t.index ["waiver_signature_digest"], name: "index_trip_signups_on_waiver_signature_digest"
    t.index ["waiver_signed_at"], name: "index_trip_signups_on_waiver_signed_at"
    t.index ["waiver_text_digest"], name: "index_trip_signups_on_waiver_text_digest"
  end

  create_table "trips", force: :cascade do |t|
    t.bigint "campsite_coordinator_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "end_date", null: false
    t.string "location", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["campsite_coordinator_id"], name: "index_trips_on_campsite_coordinator_id"
    t.index ["start_date"], name: "index_trips_on_start_date"
    t.index ["status"], name: "index_trips_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "default_password", default: false, null: false
    t.string "email"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.boolean "member", default: false, null: false
    t.string "password_digest"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true, where: "((email IS NOT NULL) AND ((email)::text <> ''::text))"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "campsite_signup_minors", "campsite_signups"
  add_foreign_key "campsite_signups", "campsite_signups", column: "guest_of_signup_id"
  add_foreign_key "campsite_signups", "campsites"
  add_foreign_key "campsite_signups", "trips"
  add_foreign_key "campsite_signups", "users"
  add_foreign_key "campsites", "campgrounds"
  add_foreign_key "campsites", "trips"
  add_foreign_key "campsites", "users", column: "registered_by_id"
  add_foreign_key "trip_signup_minors", "trip_signups"
  add_foreign_key "trips", "users", column: "campsite_coordinator_id"
end
