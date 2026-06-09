class HelpRequestReply < ApplicationRecord
  MAX_UPLOAD_SIZE = HelpRequest::MAX_UPLOAD_SIZE
  MAX_UPLOAD_SIZE_LABEL = HelpRequest::MAX_UPLOAD_SIZE_LABEL

  belongs_to :help_request
  belongs_to :user
  has_many_attached :files

  validates :message, presence: true
  validate :files_are_within_size_limit

  def admin_reply?
    user.admin_access?
  end

  private

  def files_are_within_size_limit
    files.each do |file|
      next if file.byte_size <= MAX_UPLOAD_SIZE

      errors.add(:files, "must be #{MAX_UPLOAD_SIZE_LABEL} or smaller")
    end
  end
end
