require "test_helper"

class HelpRequestTest < ActiveSupport::TestCase
  test "requires valid contact details reason and message" do
    help_request = HelpRequest.new

    assert_not help_request.valid?
    assert_includes help_request.errors[:reason], "is not included in the list"
    assert_includes help_request.errors[:name], "can't be blank"
    assert_includes help_request.errors[:email], "can't be blank"
    assert_includes help_request.errors[:message], "can't be blank"
  end

  test "links to matching user by email" do
    help_request = HelpRequest.create!(
      reason: "site_issue",
      subject: "Route page bug",
      name: "Alex",
      email: " ALEX@EXAMPLE.COM ",
      message: "The route page took a whipper."
    )

    assert_equal users(:alex), help_request.user
    assert_equal "alex@example.com", help_request.email
  end

  test "supports attached screenshots" do
    help_request = HelpRequest.create!(
      reason: "other",
      subject: "Screenshot",
      name: "Sam",
      email: "sam@example.com",
      message: "Here is a screenshot."
    )

    help_request.images.attach(io: StringIO.new("image"), filename: "screen.png", content_type: "image/png")

    assert help_request.valid?
    assert help_request.images.attached?
  end

  test "rejects screenshots over size limit" do
    help_request = HelpRequest.create!(
      reason: "other",
      subject: "Big screenshot",
      name: "Sam",
      email: "sam@example.com",
      message: "Here is a huge screenshot."
    )

    help_request.images.attach(
      io: StringIO.new("x" * (HelpRequest::MAX_UPLOAD_SIZE + 1)),
      filename: "screen.png",
      content_type: "image/png"
    )

    assert_not help_request.valid?
    assert_includes help_request.errors[:images], "must be #{HelpRequest::MAX_UPLOAD_SIZE_LABEL} or smaller"
  end

  test "supports resolved status" do
    help_request = HelpRequest.create!(
      reason: "site_issue",
      subject: "Resolved status",
      name: "Alex",
      email: "alex@example.com",
      message: "Can this be resolved?"
    )

    help_request.mark_resolved!

    assert_equal "resolved", help_request.status
    assert help_request.valid?
  end
end
