module TelegramBot::Commands
  COMMAND_LIST =  %w(start timers uptime mute)

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
  end

  # Create a new user
  def start_command(message)
    user =
      TelegramUser.where(chat_id: message.chat.id).first_or_initialize
    user.chat_id = message.chat.id
    user.name = "#{message.from.first_name} #{message.from.last_name}"
    user.save!
    api_send_message(chat_id: message.chat.id,
                     text: "Hello #{message.from.first_name}")
  end

  # Show list of active timers
  def timers_command(message)
    api_send_message(chat_id: message.chat.id,
                     text: timers,
                     parse_mode: 'HTML')
  end

  # Show uptime of bot
  def uptime_command(message)
    difference = Time.now - @start_at
    days = (difference / (3600*24)).to_i
    hours = ((difference % (3600*24)) / 3600).to_i
    mins = ((difference % (3600)) / 60).to_i
    secs = (difference % 60).to_i
    api_send_message(chat_id: message.chat.id,
                     text: "#{days}d #{hours}h #{mins}m #{secs}s")
  end

  # Mute a user on day
  def mute_command(message)
    muted_chats[message.chat.id] = Date.today
    api_send_message(chat_id: message.chat.id,
                     text: "Today I'm not going to remember you about " \
                           "timers.")
  end

  private

  def timers
    working_user_ids = []
    time_loggers =
      TimeLogger.includes(:user, :issue).all
                .map.with_index do |time_logger, index|
        working_user_ids.push(time_logger.user_id)
        "#{index + 1}. #{time_logger.user.name} " \
        "#{issue_link(time_logger.issue)}" \
        " - <b>#{time_logger.time_spent_to_s}</b>"
      end
    if time_loggers.empty?
      'Nobody works'
    else
      users = TelegramUser.active.where.not(user_id: working_user_ids)
      if users.empty?
        time_loggers.join("\n")
      else
        result = ''
        index = 0
        users.each do |user|
          next unless user.work_time?
          result += "#{index + 1}. #{user.name}\n"
          index += 1
        end
        if index > 0
          "#{time_loggers.join("\n")}\n\n" \
          "Following users are without timers:\n#{result}"
        else
          time_loggers.join("\n")
        end
      end
    end
  end
end
