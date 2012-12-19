class AddClientNudgeToUsers < ActiveRecord::Migration
  def change
    add_column :users, :client_nudge, :boolean
  end
end
