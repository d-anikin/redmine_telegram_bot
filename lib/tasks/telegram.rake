namespace :telegram do
  desc 'Start telegram bot'
  task start: :environment do
    pid_filename = Rails.root.join('tmp/pids/telegram_bot.pid')
    if File.exist? pid_filename
      pid = File.read(pid_filename).to_i
      begin
        Process.kill(0, pid)
        puts 'Telegram bot is already running'
        return exit 0
      rescue Errno::ESRCH
      end
    end

    Rails.logger = Logger.new(Rails.root.join('log', 'telegram_bot.log'))
    Rails.logger.level = Logger.const_get((ENV['LOG_LEVEL'] || 'info').upcase)

    Process.daemon(true, true)

    File.open(pid_filename, 'w') { |f| f << Process.pid }

    Rails.logger.info "Start telegram bot (PID #{Process.pid})"
    puts "Start telegram bot (PID #{Process.pid})"

    Signal.trap('TERM') { abort }

    bot = TelegramBot.new(logger: Rails.logger)

    Thread.new do
      loop do
        sleep 60
        bot.watch
      end
    end

    bot.listen
  end

  desc 'Run watcher'
  task run: :environment do
    Rails.logger = Logger.new(STDOUT)
    Rails.logger.level = Logger.const_get((ENV['LOG_LEVEL'] || 'info').upcase)
    Rails.logger.info 'Telegram bot starting'

    bot = TelegramBot.new(logger: Rails.logger)

    Thread.new do
      loop do
        sleep 60
        bot.watch
      end
    end

    bot.listen
  end

  desc 'Stop telegram bot'
  task :stop do
    pid_filename = Rails.root.join('tmp/pids/telegram_bot.pid')
    if File.exist? pid_filename
      pid = File.read(pid_filename).to_i
      begin
        Process.kill('TERM', pid)
      rescue Errno::ESRCH
        puts 'Telegram bot stopped'
      end
    else
      puts 'Telegram bot is not running'
    end
  end

 desc 'Telegram bot status'
  task :status do
    pid_filename = Rails.root.join('tmp/pids/telegram_bot.pid')
    if File.exist? pid_filename
      pid = File.read(pid_filename).to_i
      begin
        Process.kill(0, pid)
        puts 'Telegram bot is running'
      rescue Errno::ESRCH
        puts 'Telegram bot is not running'
      end
    else
      puts 'Telegram bot is not running'
    end
  end

  desc 'Telegram bot restart'
  task restart: [:stop, :start]
end
