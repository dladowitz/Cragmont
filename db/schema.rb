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

ActiveRecord::Schema[8.1].define(version: 2026_05_24_031513) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "campgrounds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "location", null: false
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["name"], name: "index_campgrounds_on_name"
  end

  create_table "campsites", force: :cascade do |t|
    t.date "arrival_date", null: false
    t.bigint "campground_id", null: false
    t.integer "car_capacity", null: false
    t.date "checkout_date", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.integer "participant_capacity", null: false
    t.string "site_number", null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["arrival_date"], name: "index_campsites_on_arrival_date"
    t.index ["campground_id"], name: "index_campsites_on_campground_id"
    t.index ["trip_id"], name: "index_campsites_on_trip_id"
  end

  create_table "trips", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "end_date", null: false
    t.string "location", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["start_date"], name: "index_trips_on_start_date"
    t.index ["status"], name: "index_trips_on_status"
  end

  add_foreign_key "campsites", "campgrounds"
  add_foreign_key "campsites", "trips"
end
