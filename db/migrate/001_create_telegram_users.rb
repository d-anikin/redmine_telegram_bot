class CreateTelegramUsers < ActiveRecord::Migration
  def self.up
    create_table :telegram_users do |t|
      t.column :user_id, :integer
      t.column :name, :string
      t.column :chat_id, :integer
      t.column :start_at, :time
      t.column :end_at, :time
      t.column :active, :boolean, default: false
    end
  end

  def self.down
    drop_table :telegram_users
  end
end
