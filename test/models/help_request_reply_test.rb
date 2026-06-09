require "test_helper"

class HelpRequestReplyTest < ActiveSupport::TestCase
  test "rejects files over size limit" do
    help_request = HelpRequest.create!(
      user: users(:alex),
      reason: "site_issue",
      subject: "Big attachment",
      name: "Alex Rivera",
      email: "alex@example.com",
      message: "I have a big file."
    )
    reply = help_request.replies.build(user: users(:alex), message: "Here is the file.")

    reply.files.attach(
      io: StringIO.new("x" * (HelpRequestReply::MAX_UPLOAD_SIZE + 1)),
      filename: "too-large.txt",
      content_type: "text/plain"
    )

    assert_not reply.valid?
    assert_includes reply.errors[:files], "must be #{HelpRequestReply::MAX_UPLOAD_SIZE_LABEL} or smaller"
  end
end
