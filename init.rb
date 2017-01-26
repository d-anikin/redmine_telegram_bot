Redmine::Plugin.register :redmine_telegram_bot do
  name 'Redmine Telegram Bot'
  author 'Dmitry Anikin'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'https://github.com/d-anikin/redmine_telegram_bot'
  author_url 'https://github.com/d-anikin'

  requires_redmine version_or_higher: '3.0.0'

  settings default: { token: nil,
                      url_base: nil },
           partial: 'settings/telegram_bot'
end
