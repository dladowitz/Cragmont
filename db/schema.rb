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

ActiveRecord::Schema[8.1].define(version: 2026_06_17_124500) do
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

  create_table "campsite_signup_payment_refunds", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.bigint "campsite_signup_payment_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "usd", null: false
    t.text "failure_reason"
    t.string "initiated_by", default: "system", null: false
    t.text "reason"
    t.string "refund_type", default: "automatic", null: false
    t.datetime "refunded_at"
    t.bigint "refunded_by_id"
    t.string "source", default: "stripe", null: false
    t.string "status", default: "pending", null: false
    t.string "stripe_refund_id"
    t.string "stripe_status"
    t.datetime "updated_at", null: false
    t.index ["campsite_signup_payment_id"], name: "idx_on_campsite_signup_payment_id_82d8e6042f"
    t.index ["initiated_by"], name: "index_campsite_signup_payment_refunds_on_initiated_by"
    t.index ["refund_type"], name: "index_campsite_signup_payment_refunds_on_refund_type"
    t.index ["refunded_by_id"], name: "index_campsite_signup_payment_refunds_on_refunded_by_id"
    t.index ["status"], name: "index_campsite_signup_payment_refunds_on_status"
    t.index ["stripe_refund_id"], name: "index_campsite_signup_payment_refunds_on_stripe_refund", unique: true, where: "(stripe_refund_id IS NOT NULL)"
  end

  create_table "campsite_signup_payments", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.bigint "campsite_signup_id", null: false
    t.datetime "checkout_expires_at"
    t.text "checkout_url"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "currency", default: "usd", null: false
    t.datetime "expired_at"
    t.datetime "expires_at"
    t.datetime "manual_paid_at"
    t.string "manual_payment_method"
    t.text "note"
    t.datetime "paid_at"
    t.string "previous_signup_status"
    t.jsonb "pricing_snapshot", default: {}, null: false
    t.integer "refunded_amount_cents", default: 0, null: false
    t.string "source", default: "stripe", null: false
    t.string "status", default: "pending", null: false
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.datetime "updated_at", null: false
    t.text "waived_reason"
    t.index ["campsite_signup_id"], name: "index_campsite_signup_payments_on_campsite_signup_id"
    t.index ["created_by_id"], name: "index_campsite_signup_payments_on_created_by_id"
    t.index ["source"], name: "index_campsite_signup_payments_on_source"
    t.index ["status"], name: "index_campsite_signup_payments_on_status"
    t.index ["stripe_checkout_session_id"], name: "index_campsite_signup_payments_on_stripe_session", unique: true, where: "(stripe_checkout_session_id IS NOT NULL)"
    t.index ["stripe_payment_intent_id"], name: "index_campsite_signup_payments_on_stripe_payment_intent_id"
  end

  create_table "campsite_signups", force: :cascade do |t|
    t.date "arrival_date"
    t.bigint "campsite_id"
    t.date "checkout_date"
    t.datetime "created_at", null: false
    t.bigint "guest_of_signup_id"
    t.integer "guest_position"
    t.string "parking_status", default: "unassigned", null: false
    t.string "status", default: "confirmed", null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.datetime "waitlist_eligible_at"
    t.datetime "waiver_acknowledged_at"
    t.text "waiver_acknowledgement_text"
    t.string "waiver_acknowledgement_text_digest"
    t.bigint "waiver_id"
    t.string "waiver_ip_address"
    t.string "waiver_signature_digest"
    t.datetime "waiver_signed_at"
    t.string "waiver_signer_name"
    t.text "waiver_text"
    t.string "waiver_text_digest"
    t.string "waiver_user_agent"
    t.index ["arrival_date"], name: "index_campsite_signups_on_arrival_date"
    t.index ["campsite_id", "parking_status"], name: "index_campsite_signups_on_campsite_parking_status"
    t.index ["campsite_id"], name: "index_campsite_signups_on_campsite_id"
    t.index ["checkout_date"], name: "index_campsite_signups_on_checkout_date"
    t.index ["guest_of_signup_id", "guest_position"], name: "index_campsite_signups_on_guest_signup_position", where: "(guest_of_signup_id IS NOT NULL)"
    t.index ["guest_of_signup_id"], name: "index_campsite_signups_on_guest_of_signup_id"
    t.index ["status"], name: "index_campsite_signups_on_status"
    t.index ["trip_id", "user_id"], name: "index_campsite_signups_on_active_trip_user", unique: true, where: "((status)::text <> 'canceled'::text)"
    t.index ["trip_id"], name: "index_campsite_signups_on_trip_id"
    t.index ["user_id"], name: "index_campsite_signups_on_user_id"
    t.index ["waitlist_eligible_at"], name: "index_campsite_signups_on_waitlist_eligible_at"
    t.index ["waiver_acknowledged_at"], name: "index_campsite_signups_on_waiver_acknowledged_at"
    t.index ["waiver_acknowledgement_text_digest"], name: "index_campsite_signups_on_waiver_acknowledgement_text_digest"
    t.index ["waiver_id"], name: "index_campsite_signups_on_waiver_id"
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

  create_table "content_pages", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "slug", null: false
    t.string "subtitle"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_content_pages_on_slug", unique: true
  end

  create_table "help_notification_subscribers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_help_notification_subscribers_on_lower_email", unique: true
  end

  create_table "help_request_replies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "help_request_id", null: false
    t.text "message", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["help_request_id"], name: "index_help_request_replies_on_help_request_id"
    t.index ["user_id"], name: "index_help_request_replies_on_user_id"
  end

  create_table "help_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "last_replied_at"
    t.text "message", null: false
    t.string "name", null: false
    t.string "reason", null: false
    t.string "status", default: "open", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["email"], name: "index_help_requests_on_email"
    t.index ["reason"], name: "index_help_requests_on_reason"
    t.index ["status"], name: "index_help_requests_on_status"
    t.index ["user_id"], name: "index_help_requests_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_roles_on_slug", unique: true
  end

  create_table "site_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "extra_night_fee_cents", default: 0, null: false
    t.integer "first_two_nights_fee_cents", default: 0, null: false
    t.text "liability_warning", default: "Cragmont is not a teaching organization. It's a social base camp. We create shared spaces to connect with other climbers. We hope you'll exchange knowledge and learn from one another. However, Cragmont does not test or vet members. It's up to you to decide what knowledge is correct and what might lead to danger. If you are new to climbing, the best way to help with these decisions is to take classes from professional guides.", null: false
    t.integer "minor_extra_night_fee_cents", default: 0, null: false
    t.integer "minor_fee_cents", default: 0, null: false
    t.integer "uncounted_minor_age_limit", default: 13, null: false
    t.datetime "updated_at", null: false
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "trip_payment_requests", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.datetime "canceled_at"
    t.bigint "canceled_by_id"
    t.datetime "checkout_expires_at"
    t.text "checkout_url"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "currency", default: "usd", null: false
    t.string "email", null: false
    t.datetime "expires_at"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.datetime "paid_at"
    t.text "reason", null: false
    t.string "status", default: "pending", null: false
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["canceled_by_id"], name: "index_trip_payment_requests_on_canceled_by_id"
    t.index ["created_by_id"], name: "index_trip_payment_requests_on_created_by_id"
    t.index ["email"], name: "index_trip_payment_requests_on_email"
    t.index ["status"], name: "index_trip_payment_requests_on_status"
    t.index ["stripe_checkout_session_id"], name: "index_trip_payment_requests_on_stripe_session", unique: true, where: "(stripe_checkout_session_id IS NOT NULL)"
    t.index ["stripe_payment_intent_id"], name: "index_trip_payment_requests_on_stripe_payment_intent_id"
    t.index ["trip_id"], name: "index_trip_payment_requests_on_trip_id"
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
    t.datetime "deleted_at"
    t.text "description"
    t.date "end_date", null: false
    t.string "location", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["campsite_coordinator_id"], name: "index_trips_on_campsite_coordinator_id"
    t.index ["deleted_at"], name: "index_trips_on_deleted_at"
    t.index ["start_date"], name: "index_trips_on_start_date"
    t.index ["status"], name: "index_trips_on_status"
  end

  create_table "user_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "default_password", default: false, null: false
    t.string "email"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.boolean "member", default: false, null: false
    t.string "password_digest"
    t.datetime "password_reset_sent_at"
    t.string "password_reset_token_digest"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true, where: "((email IS NOT NULL) AND ((email)::text <> ''::text))"
    t.index ["password_reset_token_digest"], name: "index_users_on_password_reset_token_digest", unique: true
  end

  create_table "waiver_minors", force: :cascade do |t|
    t.integer "age", null: false
    t.datetime "created_at", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "relationship", null: false
    t.datetime "updated_at", null: false
    t.bigint "waiver_id", null: false
    t.index ["age"], name: "index_waiver_minors_on_age"
    t.index ["waiver_id"], name: "index_waiver_minors_on_waiver_id"
  end

  create_table "waivers", force: :cascade do |t|
    t.bigint "campsite_signup_id"
    t.datetime "created_at", null: false
    t.bigint "trip_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.datetime "waiver_acknowledged_at"
    t.text "waiver_acknowledgement_text"
    t.string "waiver_acknowledgement_text_digest"
    t.string "waiver_ip_address"
    t.string "waiver_signature_digest"
    t.datetime "waiver_signed_at", null: false
    t.string "waiver_signer_name"
    t.text "waiver_text"
    t.string "waiver_text_digest"
    t.string "waiver_type", null: false
    t.string "waiver_user_agent"
    t.integer "waiver_year", null: false
    t.index ["campsite_signup_id"], name: "index_waivers_on_campsite_signup_id"
    t.index ["trip_id"], name: "index_waivers_on_trip_id"
    t.index ["user_id", "waiver_year"], name: "index_waivers_on_user_id_and_waiver_year"
    t.index ["user_id"], name: "index_waivers_on_user_id"
    t.index ["waiver_signature_digest"], name: "index_waivers_on_waiver_signature_digest"
    t.index ["waiver_signed_at"], name: "index_waivers_on_waiver_signed_at"
    t.index ["waiver_text_digest"], name: "index_waivers_on_waiver_text_digest"
    t.index ["waiver_type"], name: "index_waivers_on_waiver_type"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "campsite_signup_minors", "campsite_signups"
  add_foreign_key "campsite_signup_payment_refunds", "campsite_signup_payments"
  add_foreign_key "campsite_signup_payment_refunds", "users", column: "refunded_by_id"
  add_foreign_key "campsite_signup_payments", "campsite_signups"
  add_foreign_key "campsite_signup_payments", "users", column: "created_by_id"
  add_foreign_key "campsite_signups", "campsite_signups", column: "guest_of_signup_id"
  add_foreign_key "campsite_signups", "campsites"
  add_foreign_key "campsite_signups", "trips"
  add_foreign_key "campsite_signups", "users"
  add_foreign_key "campsite_signups", "waivers"
  add_foreign_key "campsites", "campgrounds"
  add_foreign_key "campsites", "trips"
  add_foreign_key "campsites", "users", column: "registered_by_id"
  add_foreign_key "help_request_replies", "help_requests"
  add_foreign_key "help_request_replies", "users"
  add_foreign_key "help_requests", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "trip_payment_requests", "trips"
  add_foreign_key "trip_payment_requests", "users", column: "canceled_by_id"
  add_foreign_key "trip_payment_requests", "users", column: "created_by_id"
  add_foreign_key "trip_signup_minors", "trip_signups"
  add_foreign_key "trips", "users", column: "campsite_coordinator_id"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "waiver_minors", "waivers"
  add_foreign_key "waivers", "campsite_signups", on_delete: :nullify
  add_foreign_key "waivers", "trips"
  add_foreign_key "waivers", "users"
end
