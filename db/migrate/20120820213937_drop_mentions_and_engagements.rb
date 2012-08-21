class DropMentionsAndEngagements < ActiveRecord::Migration
  def up
  	drop_table :mentions
  	drop_table :engagements
  end

  def down
  	create_table :mentions do |t|
      t.integer :user_id
      t.integer :post_id
      t.text :text
      t.boolean :responded, :default => false
      t.string :twi_tweet_id
      t.string :twi_in_reply_to_status_id
      t.datetime :sent_date

      t.timestamps
    end

    create_table :engagements do |t|
      t.string :date
      t.string :engagement_type
      t.string :text
      t.string :provider
      t.string :provider_post_id
      t.string  :twi_in_reply_to_status_id
      t.integer :user_id
      t.integer :account_id
      t.integer :post_id

      t.timestamps
    end
  end
end
