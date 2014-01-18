class DropTumblrFacebookColsFromUser < ActiveRecord::Migration
  def up
    remove_column :users, :fb_user_id, :integer
    remove_column :users, :fb_oauth_token, :string
    remove_column :users, :fb_oauth_secret, :string
    remove_column :users, :tum_user_id, :integer
    remove_column :users, :tum_oauth_token, :string
    remove_column :users, :tum_oauth_secret, :string
    remove_column :users, :tum_url, :string
  end

  def down
    add_column :users, :fb_user_id, :integer
    add_column :users, :fb_oauth_token, :string
    add_column :users, :fb_oauth_secret, :string
    add_column :users, :tum_user_id, :integer
    add_column :users, :tum_oauth_token, :string
    add_column :users, :tum_oauth_secret, :string
    add_column :users, :tum_url, :string
  end
end