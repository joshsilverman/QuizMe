class AddClientIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :client_id, :integer
  end
end
