class ResentNotificationLog < ActiveRecord::Base
  belongs_to :issue
  belongs_to :journal, optional: true
  belongs_to :user

  validates :notification_type, presence: true, inclusion: { in: %w[issue journal] }
  validates :recipient_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :by_user, ->(user) { where(user: user) }
  scope :today, -> { where(created_at: Date.current.all_day) }
  scope :this_week, -> { where(created_at: 1.week.ago..Time.current) }

  def self.stats_for_period(start_date, end_date = Time.current)
    where(created_at: start_date..end_date)
      .group(:notification_type)
      .sum(:recipient_count)
  end

  def formatted_created_at
    created_at.strftime('%d.%m.%Y %H:%M')
  end
end
