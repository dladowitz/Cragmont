require "test_helper"

class Admin::TripDetailsEmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    log_in_as(users(:alex))
    TripDetailsEmailTemplate.ensure_defaults!
    @template = TripDetailsEmailTemplate.find_by!(area_key: "yosemite")
    @trip = trips(:yosemite)
    campsites(:yosemite_b).update!(
      registered_by: users(:sam),
      registration_number: "YO-2026-A13"
    )
  end

  test "first visit redirects to template selection and creates editable draft" do
    get admin_trip_trip_details_email_url(@trip)

    assert_redirected_to new_admin_trip_trip_details_email_url(@trip)

    follow_redirect!
    assert_select "h2", "Start Trip Details Email"
    assert_select "label[for='trip_details_email_template_id'] .required-marker", text: "*"
    assert_select "select[name='trip_details_email_template_id'][required]" do
      assert_select "option[value='#{@template.id}']", text: "Yosemite"
    end

    assert_difference "TripDetailsEmail.count", 1 do
      post admin_trip_trip_details_email_url(@trip), params: {
        trip_details_email_template_id: @template.id
      }
    end

    assert_redirected_to edit_admin_trip_trip_details_email_url(@trip)
    email = @trip.reload.trip_details_email
    assert email.draft?
    assert_equal @template, email.trip_details_email_template

    follow_redirect!
    assert_select "input[name='trip_details_email[subject]'][required][value='#{@template.subject_template}']"
    assert_select "textarea[name='trip_details_email[body_markdown]'][required][data-markdown-preview-target='source']", text: /Campsite Assignments/
    assert_select "form[data-controller='markdown-preview'][data-markdown-preview-url-value='#{markdown_preview_admin_trip_trip_details_email_path(@trip)}']"
    assert_select "form[action='#{reset_from_template_admin_trip_trip_details_email_path(@trip)}'][method='post'][data-turbo-confirm='Throw away this draft and start over from the Yosemite template?']" do
      assert_select "input[name='_method'][value='patch']"
      assert_select "button", text: "Start over from template"
    end
    assert_select "button[type='submit'][form='trip-details-email-form'][formaction='#{preview_admin_trip_trip_details_email_path(@trip)}']", text: "Preview"
    assert_select "button[type='submit'][formaction='#{preview_admin_trip_trip_details_email_path(@trip)}']", text: "Preview and confirm"
  end

  test "preview submit saves draft and redirects to full screen preview" do
    email = create_draft!

    patch preview_admin_trip_trip_details_email_url(@trip), params: {
      trip_details_email: {
        subject: "Details for {{trip_name}}",
        body_markdown: "## Hello\n\n{{campsite_registration_info}}"
      }
    }

    assert_redirected_to preview_admin_trip_trip_details_email_url(@trip)
    assert_equal "On belay! Draft saved. Preview is ready.", flash[:notice]
    assert_equal "Details for {{trip_name}}", email.reload.subject

    follow_redirect!
    assert_response :success
    assert_select "h2", "Preview Trip Details Email"
    assert_select ".trip-details-email-subject-preview", text: "Details for Yosemite Valley Spring"
    assert_select ".trip-details-email-markdown h2", text: "Hello"
    assert_select ".trip-details-email-markdown", text: /Upper Pines A12/
    assert_select ".trip-details-email-blockers", text: /No confirmed participants/
    assert_select "button[disabled]", text: "Send trip details email"
  end

  test "saved draft preview route shows full screen preview" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    email = create_draft!
    email.update!(subject: "Details for {{trip_name}}", body_markdown: "## Hello\n\n{{campsite_registration_info}}")

    get preview_admin_trip_trip_details_email_url(@trip)

    assert_response :success
    assert_select "h2", "Preview Trip Details Email"
    assert_select ".trip-details-email-subject-preview", text: "Details for Yosemite Valley Spring"
    assert_select ".trip-details-email-markdown h2", text: "Hello"
    assert_select ".trip-details-email-recipient-table" do
      assert_select "th", text: "Participant"
      assert_select "th", text: "Email"
      assert_select "th", text: "Campsite", count: 0
      assert_select "td", text: "Sam Lee"
      assert_select "td", text: users(:sam).email
      assert_select "td", text: /Upper Pines/, count: 0
    end
  end

  test "reset from template throws away draft edits and copies current template content" do
    email = create_draft!
    email.update!(subject: "Custom subject", body_markdown: "Custom body")
    @template.update!(
      subject_template: "Template subject {{trip_dates}}",
      body_markdown: "## Fresh template\n\nUpdated details."
    )

    patch reset_from_template_admin_trip_trip_details_email_url(@trip)

    assert_redirected_to edit_admin_trip_trip_details_email_url(@trip)
    assert_equal "On belay! Draft reset from the Yosemite template.", flash[:notice]
    email.reload
    assert_equal "Template subject {{trip_dates}}", email.subject
    assert_equal "## Fresh template\n\nUpdated details.", email.body_markdown
  end

  test "send delivers email and shows locked archive with recipients" do
    create_campsite_signup!(campsite: campsites(:yosemite_a), user: users(:sam))
    email = create_draft!

    assert_emails 1 do
      post deliver_admin_trip_trip_details_email_url(@trip)
    end

    assert_redirected_to admin_trip_trip_details_email_url(@trip)
    email.reload
    assert email.sent?
    assert_equal 1, email.trip_details_email_recipients.delivered.count

    follow_redirect!
    assert_select "h2", "Trip Details Email Sent"
    assert_select ".trip-details-email-sent-summary", text: /#{email.subject}/
    assert_select "td", text: "Sam Lee"
    assert_select ".status.success-status", text: "Delivered"
    assert_select ".trip-details-email-markdown", text: /Campsite Assignments/

    patch admin_trip_trip_details_email_url(@trip), params: {
      trip_details_email: {
        subject: "Changed",
        body_markdown: "Changed"
      }
    }

    assert_redirected_to admin_trip_trip_details_email_url(@trip)
    assert_equal email.subject, email.reload.subject

    patch reset_from_template_admin_trip_trip_details_email_url(@trip)

    assert_redirected_to admin_trip_trip_details_email_url(@trip)
    assert_equal "That email has already left the anchor.", flash[:alert]
    assert_equal email.subject, email.reload.subject
  end

  test "deleted trips block creating a draft" do
    @trip.soft_delete!

    get new_admin_trip_trip_details_email_url(@trip)

    assert_redirected_to admin_trip_url(@trip)
    assert_equal "Restore this trip before changing the trip details email.", flash[:alert]
  end

  private

  def create_draft!
    @template.build_trip_details_email(@trip).tap(&:save!)
  end
end
