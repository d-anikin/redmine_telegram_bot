#!/usr/bin/env ruby

# Load Rails
DIR = File.dirname(__FILE__)
require DIR + '/../../../../config/environment'

logger = Logger.new(Rails.root.join('log/telegram_bot.log'))
logger.level = Logger::WARN

begin
  bot = TelegramBot.new(logger: logger)

  Thread.new do
    loop do
      sleep 60
      bot.watch
    end
  end

  bot.listen

rescue Exception => e
  logger.error("Error in main.rb: #{e.message}\n#{e.backtrace}")
ensure
  logger.warn("main.rb: Done")
end
