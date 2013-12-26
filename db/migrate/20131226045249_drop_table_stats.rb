class DropTableStats < ActiveRecord::Migration
  def up
    drop_table :stats
  end

  def down
    create_table :stats do |t|
      t.date "date"
      t.integer "followers", :default => 0
      t.integer "total_followers", :default => 0
      t.integer "retweets", :default => 0
      t.integer "mentions", :default => 0
      t.integer "questions_answered", :default => 0
      t.integer "internal_answers", :default => 0
      t.integer "twitter_answers", :default => 0
      t.integer "active_users", :default => 0
      t.text "active_user_ids", :default => ""
      t.integer "asker_id"

      t.timestamps
    end
  end
end
