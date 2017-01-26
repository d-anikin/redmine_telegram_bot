class TelegramUsersController < ApplicationController
  unloadable

  def index
    @telegram_users = TelegramUser.all
    @users = User.all
  end

  def update
    @telegram_users =
      TelegramUser.update(params[:telegram_users].keys,
                          params[:telegram_users].values)
    flash[:notice] = 'Accepted'
    redirect_to :back
  end
end
