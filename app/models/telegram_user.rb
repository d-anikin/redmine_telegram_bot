class TelegramUser < ActiveRecord::Base
  attr_accessible :start_at, :end_at, :user_id, :active

  scope :active, -> { where(active: true).where.not(user_id: nil) }

  def initialize(attributes = nil, options = {})
    super
    self.start_at = '09:00'.to_time
    self.end_at = '18:00'.to_time
  end

  def start_at_to_s
    start_at.strftime('%H:%M')
  end

  def end_at_to_s
    end_at.strftime('%H:%M')
  end

  def work_time?
    time = Time.now
    !time.hour.eql?(13) && time.hour >= start_at.hour && time.hour < end_at.hour
  end
end
