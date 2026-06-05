require "test_helper"

class Admin::CampsitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:alex))
  end

  test "can render new campsite form" do
    get new_admin_trip_campsite_url(trips(:yosemite))

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select ".panel-header", text: /Yosemite Valley Spring/
    assert_select "select[name='campsite[registered_by_id]']"
    assert_select "input[name='campsite[registration_number]']"
    assert_select "input[name='campsite[arrival_date]'][min='2026-06-12'][max='2026-06-15']"
    assert_select "input[name='campsite[checkout_date]'][min='2026-06-12'][max='2026-06-15']"
  end

  test "can add campsite to trip" do
    assert_difference "Campsite.count", 1 do
      post admin_trip_campsites_url(trips(:yosemite)), params: {
        campsite: {
          campground_id: campgrounds(:upper_pines).id,
          registered_by_id: users(:sam).id,
          registration_number: "YO-2026-A14",
          site_number: "A14",
          arrival_date: "2026-06-13",
          checkout_date: "2026-06-15",
          participant_capacity: 8,
          car_capacity: 2,
          notes: "Extra site."
        }
      }
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    campsite = Campsite.order(:created_at).last
    assert_equal users(:sam), campsite.registered_by
    assert_equal "YO-2026-A14", campsite.registration_number
  end

  test "rejects campsite dates outside trip dates" do
    assert_no_difference "Campsite.count" do
      post admin_trip_campsites_url(trips(:yosemite)), params: {
        campsite: {
          campground_id: campgrounds(:upper_pines).id,
          site_number: "A14",
          arrival_date: "2026-06-11",
          checkout_date: "2026-06-16",
          participant_capacity: 8,
          car_capacity: 2,
          notes: "Extra site."
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", text: /Arrival date must be within the trip dates/
    assert_select ".form-errors", text: /Checkout date must be within the trip dates/
  end

  test "can render edit campsite form" do
    get edit_admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a))

    assert_response :success
    assert_select "h1", "Admin Dashboard"
    assert_select ".panel-header", text: /Yosemite Valley Spring/
    assert_select ".form-actions input[type='submit']"
    assert_select ".form-actions a.button.secondary", text: "Cancel"
    assert_select ".form-actions .danger-form-action [data-controller='modal'] button.button.danger.secondary", text: "Delete campsite"
    assert_select "dialog.confirmation-modal", text: /Delete campsite\?/
    assert_select "button[form='delete-campsite-#{campsites(:yosemite_a).id}']", text: "Delete campsite"
    assert_select "form#delete-campsite-#{campsites(:yosemite_a).id}[action='#{admin_trip_campsite_path(trips(:yosemite), campsites(:yosemite_a))}'][method='post'].hidden-delete-form"
  end

  test "edit campsite form disables delete when campsite has participants" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    get edit_admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a))

    assert_response :success
    assert_select ".form-actions .danger-form-action .disabled-tooltip[aria-label='Cannot delete campsite with participants signed up. Remove them or move to the waitlist first']" do
      assert_select "button.button.danger.secondary[disabled]", text: "Delete campsite"
    end
    assert_select ".form-actions .danger-form-action [data-controller='modal']", count: 0
  end

  test "edit campsite form allows delete when only canceled payment history remains" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), status: "canceled")
    signup.payments.create!(source: "manual", status: "refunded", amount_cents: 1000, refunded_amount_cents: 1000, manual_payment_method: "cash", manual_paid_at: Time.current, paid_at: Time.current)

    get edit_admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a))

    assert_response :success
    assert_select ".form-actions .danger-form-action [data-controller='modal'] button.button.danger.secondary", text: "Delete campsite"
    assert_select ".form-actions .danger-form-action .disabled-tooltip", count: 0
  end

  test "can update campsite" do
    patch admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a)), params: {
      campsite: {
        campground_id: campgrounds(:upper_pines).id,
        registered_by_id: users(:alex).id,
        registration_number: "YO-2026-A12B",
        site_number: "A12B",
        arrival_date: campsites(:yosemite_a).arrival_date,
        checkout_date: campsites(:yosemite_a).checkout_date,
        participant_capacity: 7,
        car_capacity: 2,
        notes: campsites(:yosemite_a).notes
      }
    }

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "A12B", campsites(:yosemite_a).reload.site_number
    assert_equal 7, campsites(:yosemite_a).participant_capacity
    assert_equal users(:alex), campsites(:yosemite_a).registered_by
    assert_equal "YO-2026-A12B", campsites(:yosemite_a).registration_number
  end

  test "can delete campsite" do
    assert_difference "Campsite.count", -1 do
      delete admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a))
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
  end

  test "can delete campsite with only canceled payment history" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam), status: "canceled")
    signup.payments.create!(source: "manual", status: "refunded", amount_cents: 1000, refunded_amount_cents: 1000, manual_payment_method: "cash", manual_paid_at: Time.current, paid_at: Time.current)

    assert_difference "Campsite.count", -1 do
      assert_no_difference "CampsiteSignup.count" do
        delete admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a))
      end
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_nil signup.reload.campsite
  end

  test "cannot delete campsite with participants signed up" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))

    assert_no_difference "Campsite.count" do
      delete admin_trip_campsite_url(trips(:yosemite), campsites(:yosemite_a))
    end

    assert_redirected_to admin_trip_url(trips(:yosemite))
    assert_equal "Cannot delete campsite with participants signed up. Remove them or move to the waitlist first", flash[:alert]
  end
end
