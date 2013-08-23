class AddLastEmailRequestAtToUsers < ActiveRecord::Migration
  def change
    add_column :users, :last_email_request_at, :datetime
  end
end
