require "test_helper"

class WaiverRequestsControllerTest < ActionDispatch::IntegrationTest
  test "user can view standalone waiver request" do
    token = users(:sam).signed_id(purpose: :standalone_waiver_request)

    get waiver_request_url(token)

    assert_response :success
    assert_select "h1", "Cragmont Waiver"
    assert_select "p.muted", text: /Sam Lee, sign your #{Date.current.year} Cragmont waiver/
    assert_select "form[action='#{waiver_request_path(token)}']"
    assert_select ".signup-kind-options", text: /Add minors \(under 18\)/
    assert_select "input[type='checkbox'][name='waiver[with_minors]'][value='1']"
    assert_select ".minor-fields", text: /Minor information\s+\(Max 2\)/
    assert_select ".minor-fields .minor-field-row", count: 2
    assert_select ".minor-fields .minor-field-row[hidden]", count: 1
    assert_select ".minor-fields input[data-required-for-minor='true']", count: 8
    assert_select ".minor-fields button.add-person-link", text: "Add another minor"
    assert_select "button", "Submit Waiver"
  end

  test "user can sign standalone waiver request" do
    token = users(:sam).signed_id(purpose: :standalone_waiver_request)

    assert_difference "Waiver.count", 1 do
      post waiver_request_url(token), params: {
        waiver: {
          waiver_signature_data: SIGNATURE_DATA_URL,
          waiver_acknowledged_at: Time.current.iso8601
        }
      }
    end

    waiver = users(:sam).waivers.order(:created_at).last
    assert_redirected_to root_url
    assert_equal Date.current.year, waiver.waiver_year
    assert waiver.annual_adult?
    assert_nil waiver.trip
    assert_nil waiver.campsite_signup
    assert waiver.document.attached?
    assert_equal "On belay! Your Cragmont waiver is signed.", flash[:notice]
  end

  test "user can sign standalone waiver request with minors" do
    token = users(:sam).signed_id(purpose: :standalone_waiver_request)

    assert_difference [ "Waiver.count", "WaiverMinor.count" ], 1 do
      post waiver_request_url(token), params: {
        waiver: {
          with_minors: "1",
          waiver_signature_data: SIGNATURE_DATA_URL,
          waiver_acknowledged_at: Time.current.iso8601,
          waiver_minors_attributes: {
            "0" => { first_name: "Mika", last_name: "Lee", age: "12", relationship: "Child" }
          }
        }
      }
    end

    waiver = users(:sam).waivers.order(:created_at).last
    minor = waiver.waiver_minors.first
    assert_redirected_to root_url
    assert waiver.trip_minor?
    assert_nil waiver.trip
    assert_nil waiver.campsite_signup
    assert_equal "Mika Lee", minor.full_name
    assert_equal 12, minor.age
    assert_equal "Child", minor.relationship
    assert_includes waiver.waiver_text, TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT
    assert_includes waiver.waiver_acknowledgement_text, TripSignupWaiver::MINOR_RESPONSIBILITY_TEXT
    assert_equal "Mika Lee", waiver.minors_summary
    assert waiver.document.attached?
  end

  test "standalone waiver with minors requires minor information" do
    token = users(:sam).signed_id(purpose: :standalone_waiver_request)

    assert_no_difference "Waiver.count" do
      post waiver_request_url(token), params: {
        waiver: {
          with_minors: "1",
          waiver_signature_data: SIGNATURE_DATA_URL,
          waiver_acknowledged_at: Time.current.iso8601
        }
      }
    end

    assert_redirected_to waiver_request_url(token)
    assert_equal "Please enter minor information before signing the waiver.", flash[:alert]
  end

  test "standalone waiver rejects incomplete minor information" do
    token = users(:sam).signed_id(purpose: :standalone_waiver_request)

    assert_no_difference "Waiver.count" do
      post waiver_request_url(token), params: {
        waiver: {
          with_minors: "1",
          waiver_signature_data: SIGNATURE_DATA_URL,
          waiver_acknowledged_at: Time.current.iso8601,
          waiver_minors_attributes: {
            "0" => { first_name: "Mika", last_name: "", age: "12", relationship: "Child" }
          }
        }
      }
    end

    assert_redirected_to waiver_request_url(token)
    assert_match(/Last name can't be blank/, flash[:alert])
  end

  test "invalid standalone waiver request redirects home" do
    get waiver_request_url("not-a-real-token")

    assert_redirected_to root_url
    assert_equal "Wow, that was a whipper. That waiver link is invalid.", flash[:alert]
  end
end
