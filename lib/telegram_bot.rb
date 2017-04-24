require 'telegram/bot'

class TelegramBot
  attr_reader :telegram, :muted_chats, :logger
  include TelegramBot::Commands

  def initialize(options = {})
    @token = Setting.plugin_redmine_telegram_bot['token']
    @url_base = Setting.plugin_redmine_telegram_bot['url_base']
    @telegram = Telegram::Bot::Client.new(@token)
    @start_at = Time.now
    @muted_chats = {}
    @logger = options[:logger] || Logger.new(Rails.root.join('log/telegram_bot.log'))
  end

  def watch
    time = Time.now
    stop_zombies
    to_lunch if time.min.zero? && time.hour.eql?(13)
    stop_not_working_users if time.min.zero?
    if (time >= '16:30'.to_time) && (time < '17:00'.to_time)
      daily_meeting if time.min.in? [0, 5, 10]
      send_to_general_about_daily_meeting if time.min == 0
    elsif time.min.in? [0, 15, 30, 45]
      remeber_no_trackers
    end
  rescue Exception => e
    logger.error("Error in method 'watch': #{e.message}\n#{e.backtrace}")
  end

  def stop_zombies
    TimeLogger.all.each do |time_logger|
      next unless time_logger.zombie?
      time_logger.stop
      telegram_user = TelegramUser.find_by(user_id: time_logger.user_id)
      next unless telegram_user.present?
      api_send_message(
        chat_id: telegram_user.chat_id,
        text: 'The timer has been stopped!' \
              "\nYou have worked on an issue #{issue_link(time_logger.issue)}",
        parse_mode: 'HTML'
      )
    end
  end

  def to_lunch
    TimeLogger.all.each do |time_logger|
      time_logger.stop
      telegram_user = TelegramUser.find_by(user_id: time_logger.user_id)
      next unless telegram_user.present?
      api_send_message(
        chat_id: telegram_user.chat_id,
        text: 'Bon Appetit!' \
              "\nYou have worked on an issue #{issue_link(time_logger.issue)}",
        parse_mode: 'HTML'
      )
    end
  end

  def send_to_general_about_daily_meeting
     api_send_message(chat_id: -121031024,
                      text: 'Daily Scrum Meeting, please stand up!')
  end

  def daily_meeting
    TimeLogger.all.each do |time_logger|
      time_logger.stop
      telegram_user = TelegramUser.find_by(user_id: time_logger.user_id)
      next unless telegram_user.present?
      api_send_message(
        chat_id: telegram_user.chat_id,
        text: 'Daily Scrum Meeting!' \
              "\nYou have worked on an issue #{issue_link(time_logger.issue)}",
        parse_mode: 'HTML'
      )
    end
  end

  def remeber_no_trackers
    return false unless Time.now.wday.in? 1..5
    working_user_ids = TimeLogger.all.pluck(:user_id)
    TelegramUser.active
                .where.not(user_id: working_user_ids)
                .each do |telegram_user|
      next unless telegram_user.work_time?
      next if muted_chats[telegram_user.chat_id].eql? Date.today

      api_send_message(
        chat_id: telegram_user.chat_id,
        text: "#{telegram_user.name} start a timer, please"
      )
    end
  end

  def stop_not_working_users
    return false unless Time.now.wday.in? 1..5
    TimeLogger.all.each do |time_logger|
      telegram_user = TelegramUser.find_by(user_id: time_logger.user_id)
      next if !telegram_user.present? || telegram_user.work_time?
      time_logger.stop
      api_send_message(
        chat_id: telegram_user.chat_id,
        text: 'The timer has been stopped! Enjoy yourself!' \
              "\nYou have worked on an issue #{issue_link(time_logger.issue)}",
        parse_mode: 'HTML'
      )
    end
  end

  def listen
    logger.info 'Telegram bot listening'
    telegram.listen do |message|
      begin
        logger.info("Message: #{message.inspect}")
        command = message.text.sub('/', '')
        if command.in? COMMAND_LIST
          send("#{command}_command", message)
        else
          api_send_message(chat_id: message.chat.id,
                           text: message.text)
        end
      rescue Exception => e
        logger.error("Error in method 'listen': #{e.message}\n#{e.backtrace}")
      end
    end
  end

  private

  def issue_link(issue)
    "<a href='#{@url_base}/issues/#{issue.id}'>##{issue.id}</a>" \
    " #{issue.subject.truncate(60)}"
  end

  def api_send_message(options)
    telegram.api.send_message(options)
  end
end
