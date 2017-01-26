#!/usr/bin/env ruby

# Load Rails
DIR = File.dirname(__FILE__)
require DIR + '/../../../../config/environment'

bot = TelegramBot.new

watcher = Thread.new do
  loop do
    sleep 60
    bot.watch
  end
end

bot.listen
