class TripReadinessCompletion < ApplicationRecord
  belongs_to :trip
  belongs_to :completed_by, class_name: "User", optional: true

  validates :task_key, presence: true
  validates :completed_at, presence: true
  validates :task_key, uniqueness: { scope: :trip_id }
  validate :task_key_is_completable

  private

  def task_key_is_completable
    return if task_key.blank?
    return if TripReadinessChecklist.completable_task_key?(task_key, trip: trip)

    errors.add(:task_key, "is not included in the list")
  end
end
