Rails.application.routes.draw do
  match 'telegram_users', to: 'telegram_users#index', via: [:get]
  match 'telegram_users', to: 'telegram_users#update', via: [:post]
end
