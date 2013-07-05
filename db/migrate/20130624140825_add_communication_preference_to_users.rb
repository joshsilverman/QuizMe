class AddCommunicationPreferenceToUsers < ActiveRecord::Migration
  def change
    add_column :users, :communication_preference, :integer, :default => 1
  end
end
