require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "public header links signed in user name to profile" do
    log_in_as(users(:alex))

    get trips_url

    assert_response :success
    assert_select ".public-nav a[href='#{profile_path}']", text: "Alex Rivera"
  end

  test "logged in user can view profile" do
    log_in_as(users(:alex))

    get profile_url

    assert_response :success
    assert_select "body.profile-show-page"
    assert_select ".background-image-caption", "Castle Valley, UT. Castleton Tower."
    assert_select "h1", "Alex Rivera"
    assert_select ".details-list dt", text: "Email"
    assert_select ".details-list dd", text: "alex@example.com"
    assert_select ".details-list dt", text: "Phone"
    assert_select ".details-list dd", text: "555-0100"
    assert_select ".details-list dt", text: "Club member"
    assert_select ".details-list dd", text: "Yes"
    assert_select ".details-list dt", text: "Current Waiver"
    assert_select "a[href='#{new_profile_waiver_path}']", text: "Missing"
    assert_select "a[href='#{edit_profile_path}']", text: "Edit profile"
    assert_select "button", text: "Delete account", count: 0
    assert_select "h2", text: "Transactions"
    assert_select ".transactions-table", count: 0
    assert_select "p.muted", text: "No completed payments yet."
    assert_select "h2", text: "Inbox"
    assert_select "a[href='#{help_requests_path}']", text: "All Help Requests"
    assert_select "p.muted", text: "No help requests yet."
    assert_select "dialog.confirmation-modal", count: 0
    assert_select "a", text: "Yosemite Valley Spring"
    assert_select "a[href='#{admin_trip_path(trips(:yosemite))}']", text: "Manage trip"
  end

  test "profile shows current waiver modal and download action" do
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    waiver = attach_test_waiver_to(signup).waiver
    log_in_as(users(:sam))

    get profile_url

    assert_response :success
    inline_path = "#{rails_blob_path(waiver.document, disposition: "inline")}#view=FitH"
    download_path = rails_blob_path(waiver.document, disposition: "attachment")
    assert_select ".details-list dt", text: "Current Waiver"
    assert_select "button[aria-controls='profile-current-waiver']", text: waiver.waiver_signed_at.strftime("%m/%d/%y")
    assert_select "dialog#profile-current-waiver" do
      assert_select "h2", "Waiver"
      assert_select "iframe.waiver-document-iframe[src='#{inline_path}']"
      assert_select "a[href='#{download_path}']", text: "Download Waiver"
    end
  end

  test "user can sign current waiver from profile" do
    log_in_as(users(:sam))

    assert_difference "Waiver.count", 1 do
      post profile_waiver_url, params: {
        waiver: {
          waiver_signature_data: SIGNATURE_DATA_URL,
          waiver_acknowledged_at: Time.current.iso8601
        }
      }
    end

    waiver = users(:sam).waivers.order(:created_at).last
    assert_redirected_to profile_url
    assert_equal Date.current.year, waiver.waiver_year
    assert waiver.annual_adult?
    assert waiver.document.attached?
    assert_equal "On belay! Your current waiver is signed.", flash[:notice]
  end

  test "profile inbox shows the five most recent help requests" do
    user = users(:alex)
    6.times do |index|
      HelpRequest.create!(
        user: user,
        reason: "site_issue",
        subject: "Profile inbox request #{index}",
        name: user.full_name,
        email: user.email,
        message: "Profile inbox request #{index}",
        created_at: index.days.ago
      )
    end
    HelpRequest.create!(
      user: users(:sam),
      reason: "other",
      subject: "Sam request",
      name: "Sam Lee",
      email: "sam@example.com",
      message: "Sam should not show"
    )
    log_in_as(user)

    get profile_url

    assert_response :success
    assert_select "h2", text: "Inbox"
    assert_select ".profile-inbox-table tbody tr", count: 5
    assert_select "td", text: /Report site issue/, count: 5
    assert_select "td", text: /Sam should not show/, count: 0
    assert_select "a[href='#{help_requests_path}']", text: "All Help Requests"
  end

  test "profile hides coordinated trips section when user coordinates no trips" do
    log_in_as(users(:sam))

    get profile_url

    assert_response :success
    assert_select "h2", text: "Coordinated trips", count: 0
    assert_select "p.muted", text: "This user is not assigned as a campsite coordinator yet.", count: 0
  end

  test "profile transactions show only completed payments for signed in user" do
    user = users(:sam)
    user_signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: user)
    user_signup.payments.create!(
      source: "stripe",
      status: "paid",
      amount_cents: 4000,
      paid_at: Time.zone.local(2026, 6, 1, 9, 0),
      stripe_payment_intent_id: "pi_profile_sam"
    )
    user_signup.payments.create!(
      source: "stripe",
      status: "pending",
      amount_cents: 9000
    )
    other_user = User.create!(
      first_name: "Other",
      last_name: "Participant",
      email: "other-profile-transactions@example.com",
      password: "password"
    )
    other_signup = create_campsite_signup!(campsite: campsites(:jtree_a), user: other_user)
    other_signup.payments.create!(
      source: "stripe",
      status: "paid",
      amount_cents: 7000,
      paid_at: Time.zone.local(2026, 6, 1, 10, 0)
    )
    log_in_as(user)

    with_env("STRIPE_ACCOUNT_ID" => "acct_profile_123") do
      get profile_url
    end

    assert_response :success
    assert_select "h2", text: "Transactions"
    assert_select "table.transactions-table" do
      transaction_rows = css_select("tbody").first.children.select { |child| child.element? && child.name == "tr" }

      assert_equal [
        "Trip",
        "Participant",
        "Amount Paid",
        "Status",
        "Paid At",
        "Details"
      ], css_select("thead").first.css("th").map { |header| header.text.strip }
      assert_equal 1, transaction_rows.size
      assert_select "a[href='#{trip_path(trips(:yosemite))}']", text: "Yosemite Valley Spring"
      assert_select "td", text: "Sam Lee"
      assert_select "td", text: "$40.00"
      assert_select ".transaction-status", text: "Paid"
      assert_select "button", text: "View"
      assert_select "td", text: "$90.00", count: 0
      assert_select "td", text: "$70.00", count: 0
      assert_select "td", text: "Other Participant", count: 0
    end
    assert_select "dialog.transaction-details-modal", text: /Payment details/
    assert_select "dialog.transaction-details-modal" do
      assert_select "dt", text: "Trip"
      assert_select "a[href='#{trip_path(trips(:yosemite))}']", text: "Yosemite Valley Spring"
      assert_select "dt", text: "Participant"
      assert_select "dt", text: "Status"
      assert_select "dt", text: "Amount"
      assert_select "dt", text: "Amount Refunded"
      assert_select "dt", text: "Source", count: 0
      assert_select "dt", text: "Remaining refundable", count: 0
      assert_select "dt", text: "Waived reason", count: 0
      assert_select "a[href='https://dashboard.stripe.com/acct_profile_123/test/payments/pi_profile_sam']", count: 0
    end
  end

  test "profile edit excludes club member control" do
    log_in_as(users(:alex))

    get edit_profile_url

    assert_response :success
    assert_select "body.profile-edit-page"
    assert_select ".background-image-caption", "Castle Valley, UT. Castleton Tower."
    assert_select "input[name='user[first_name]'][value='Alex']"
    assert_select "input[name='user[last_name]'][value='Rivera']"
    assert_select "input[name='user[email]'][value='alex@example.com']"
    assert_select "input[name='user[phone]'][value='555-0100']"
    assert_select ".password-visibility-field[data-controller='password-visibility']", count: 2
    assert_select "button.password-visibility-toggle[aria-label='Show password']", count: 2
    assert_select "input[type='password'][data-password-visibility-target='input']", count: 2
    assert_select "input[type='radio'][name='user[member]']", count: 0
    assert_select "fieldset.radio-field", count: 0
    assert_select "h2", text: "Account"
    assert_select "button", text: "Delete account"
    assert_select "dialog.confirmation-modal", text: /Are you sure you want to delete your account\?/
    assert_select "dialog.confirmation-modal", text: /This will delete all history and current trips/
    assert_select "label[for='confirmation_text']", text: /Type Delete Me to Confirm/
    assert_select "label[for='confirmation_text'] .required-marker", text: "*"
    assert_select "input[name='confirmation_text'][required]"
    assert_select "input[type='submit'][disabled]", value: "Delete account"
  end

  test "logged in user can update profile without changing member status" do
    log_in_as(users(:sam))

    patch profile_url, params: {
      user: {
        first_name: "Samuel",
        last_name: users(:sam).last_name,
        email: "samuel@example.com",
        phone: "555-0199",
        member: "1",
        password: "",
        password_confirmation: ""
      }
    }

    assert_redirected_to profile_url
    users(:sam).reload
    assert_equal "Samuel", users(:sam).first_name
    assert_equal "samuel@example.com", users(:sam).email
    assert_equal "555-0199", users(:sam).phone
    assert_not users(:sam).member?
  end

  test "delete account requires confirmation text" do
    log_in_as(users(:sam))

    assert_no_difference "User.count" do
      delete profile_url, params: { confirmation_text: "Delete" }
    end

    assert_redirected_to profile_url
    assert_equal "Type Delete Me to confirm account deletion.", flash[:alert]
  end

  test "user can delete account and trip history" do
    user = User.create!(first_name: "Temporary", last_name: "Member", email: "temporary@example.com", password: "password")
    signup = create_campsite_signup!(campsite: campsites(:yosemite_a), user: user)
    campsites(:yosemite_b).update!(registered_by: user)
    trips(:jtree).update!(campsite_coordinator: user)
    log_in_as(user)

    assert_difference "User.count", -1 do
      assert_difference "CampsiteSignup.count", -1 do
        delete profile_url, params: { confirmation_text: "Delete Me" }
      end
    end

    assert_redirected_to root_url
    assert_equal "Your account was deleted.", flash[:notice]
    assert_nil CampsiteSignup.find_by(id: signup.id)
    assert_nil campsites(:yosemite_b).reload.registered_by
    assert_nil trips(:jtree).reload.campsite_coordinator
  end

  test "logged out user is redirected from profile" do
    get profile_url

    assert_redirected_to new_session_url
  end

  private

  def log_in_as(user)
    post session_url, params: { email: user.email, password: "password" }
  end

  def with_env(values)
    originals = values.keys.index_with { |key| ENV[key] }
    values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    originals.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
