class AddRoleToUsers < ActiveRecord::Migration
  def change
  	#add account attrs to users
    add_column :users, :role, :string, :default => 'user'
    add_column :users, :name, :string
    add_column :users, :fb_user_id, :integer
    add_column :users, :fb_oauth_token, :string
    add_column :users, :fb_oauth_secret, :string
    add_column :users, :tum_user_id, :integer
    add_column :users, :tum_oauth_token, :string
    add_column :users, :tum_oauth_secret, :string
    add_column :users, :tum_url, :string
    add_column :users, :posts_per_day, :integer
    add_column :users, :description, :text

    remove_column :users, :provider
    remove_column :users, :uid

    #add responded to to engagements
    add_column :engagements, :responded_to, :boolean

    #remove and recreate HABTM topic table
    drop_table :accountstopics
    create_table :askertopics do |t|
      t.integer :asker_id
      t.integer :topic_id

      t.timestamps
    end

    #update all account_id fks with asker_id
    remove_column :engagements, :account_id
    add_column :engagements, :asker_id, :integer
    remove_column :posts, :account_id
    add_column :posts, :asker_id, :integer
    remove_column :post_queues, :account_id
    add_column :post_queues, :asker_id, :integer
    remove_column :stats, :account_id
    add_column :stats, :asker_id, :integer
    remove_column :questions, :created_for_account_id
    add_column :questions, :created_for_asker_id, :integer

  end
end
