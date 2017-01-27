require 'telegram/bot'

class TelegramBot
  attr_reader :telegram

  def initialize
    @token = Setting.plugin_redmine_telegram_bot['token']
    @url_base = Setting.plugin_redmine_telegram_bot['url_base']
    @telegram = Telegram::Bot::Client.new(@token)
    @start_at = Time.now
  end

  def uptime
    difference = Time.now - @start_at
    days = (difference / (3600*24)).to_i
    hours = ((difference % (3600*24)) / 3600).to_i
    mins = ((difference % (3600)) / 60).to_i
    secs = (difference % 60).to_i
    "#{days} days, #{hours} hours, #{mins} minutes and #{secs} seconds"
  end

  def watch
    time = Time.now
    stop_zombies
    to_lunch if time.min.zero? && time.hour.eql?(13)
    remeber_no_trackers if time.min.in? [15, 30, 45]
    stop_not_working_users if time.min.zero?
  end

  def stop_zombies
    TimeLogger.all.each do |time_logger|
      next unless time_logger.zombie?
      time_logger.stop
      telegram_user = TelegramUser.find_by(user_id: time_logger.user_id)
      next unless telegram_user.present?
      telegram.api.send_message(
        chat_id: telegram_user.chat_id,
        text: 'Таймер остановлен!' \
              "\nВы работали над задачей #{issue_link(time_logger.issue)}",
        parse_mode: 'HTML'
      )
    end
  end

  def to_lunch
    TimeLogger.all.each do |time_logger|
      time_logger.stop
      telegram_user = TelegramUser.find_by(user_id: time_logger.user_id)
      next unless telegram_user.present?
      telegram.api.send_message(
        chat_id: telegram_user.chat_id,
        text: 'Обед! Приятного аппетита!' \
              "\nВы работали над задачей #{issue_link(time_logger.issue)}",
        parse_mode: 'HTML'
      )
    end
  end

  def remeber_no_trackers
    return true if Time.now.wday >= 6
    working_user_ids = TimeLogger.all.pluck(:user_id)
    TelegramUser.active
                .where.not(user_id: working_user_ids)
                .each do |telegram_user|
      next unless telegram_user.work_time?
      telegram.api.send_message(
        chat_id: telegram_user.chat_id,
        text: "#{telegram_user.name} включи таймер, пожалуйста"
      )
    end
  end

  def stop_not_working_users
    return true if Time.now.wday >= 6
    TimeLogger.all.each do |time_logger|
      telegram_user = TelegramUser.find_by(user_id: time_logger.user_id)
      next if !telegram_user.present? || telegram_user.work_time?
      time_logger.stop
      telegram.api.send_message(
        chat_id: telegram_user.chat_id,
        text: 'Таймер остановлен! Приятного отдыха!' \
              "\nВы работали над задачей #{issue_link(time_logger.issue)}",
        parse_mode: 'HTML'
      )
    end
  end

  def listen
    telegram.listen do |message|
      begin
        case message.text
        when '/timers'
          telegram.api.send_message(chat_id: message.chat.id,
                                    text: timers,
                                    parse_mode: 'HTML')
        when '/start'
          user =
            TelegramUser.where(chat_id: message.chat.id)
                        .first_or_initialize do |user|
                          user.chat_id = message.chat.id
                          user.name = "#{message.from.first_name} #{message.from.last_name}"
                        end
          user.save! if user.new_record?
          telegram.api.send_message(chat_id: message.chat.id,
                                    text: "Hello, #{message.from.first_name}")
        when '/uptime'
           telegram.api.send_message(chat_id: message.chat.id,
                                     text: uptime)
        else
          telegram.api.send_message(chat_id: message.chat.id,
                                    text: message.text)
        end
      rescue Exception => e
        if Rails.env.development?
          telegram.api.send_message(chat_id: message.chat.id, text: e.message)
          puts e.message
          puts e.backtrace
        else
          telegram.api.send_message(chat_id: message.chat.id,
                                    text: 'Some things went wrong')
        end
      end
    end
  end

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
      'Почему-то никто не работает :('
    else
      users = TelegramUser.active.where.not(user_id: working_user_ids)
      if users.empty?
        time_loggers.join("\n")
      else
        result = ''
        index = 0
        users.each do |user|
          next unless user.work_time?
          result += "#{index + 1}. #{user.name}"
          index += 1
        end
        if index > 0
          "#{time_loggers.join("\n")}\n\n" \
          "Нет таймера у следующих пользователей:\n#{result}"
        else
          time_loggers.join("\n")
        end
      end
    end
  end

  private

  def issue_link(issue)
    "<a href='#{@url_base}/issues/#{issue.id}'>##{issue.id}</a>" \
    " #{issue.subject.truncate(60)}"
  end
end
