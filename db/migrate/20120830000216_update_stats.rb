class UpdateStats < ActiveRecord::Migration
  def up
  	drop_table :stats
		create_table :stats do |t|
			t.integer "followers", :default => 0
			t.integer "total_followers", :default => 0
			t.integer "retweets", :default => 0
			t.integer "total_retweets", :default => 0
			t.integer "mentions", :default => 0
			t.integer "total_mentions", :default => 0
			t.integer "questions_answered", :default => 0
			t.integer "total_questions_answered", :default => 0
			t.integer "internal_answers", :default => 0
			t.integer "total_internal_answers", :default => 0
			t.integer "twitter_answers", :default => 0
			t.integer "total_twitter_answers", :default => 0
			t.integer "active_users", :default => 0
			t.text "active_user_ids"
			t.integer "asker_id"

		  t.timestamps
		end
  end

  def down
  	drop_table :stats
		create_table :stats do |t|
	    t.string    "date"
	    t.integer   "followers"
	    t.integer   "friends"
	    t.integer   "rts"
	    t.integer   "mentions"
	    t.integer   "one_week_inactive_users"
	    t.timestamp "created_at"
	    t.timestamp "updated_at"
	    t.integer   "asker_id"
	    t.integer   "twitter_posts",                     :default => 0
	    t.integer   "tumblr_posts",                      :default => 0
	    t.integer   "facebook_posts",                    :default => 0
	    t.integer   "internal_posts",                    :default => 0
	    t.integer   "twitter_answers",                   :default => 0
	    t.integer   "tumblr_answers",                    :default => 0
	    t.integer   "facebook_answers",                  :default => 0
	    t.integer   "internal_answers",                  :default => 0
	    t.integer   "twitter_daily_active_users"
	    t.integer   "twitter_weekly_active_users"
	    t.integer   "twitter_monthly_active_users"
	    t.integer   "twitter_one_day_inactive_users"
	    t.integer   "twitter_one_week_inactive_users"
	    t.integer   "twitter_one_month_inactive_users"
	    t.integer   "twitter_daily_churn"
	    t.integer   "twitter_weekly_churn"
	    t.integer   "twitter_monthly_churn"
	    t.integer   "internal_daily_active_users"
	    t.integer   "internal_weekly_active_users"
	    t.integer   "internal_monthly_active_users"
	    t.integer   "internal_one_day_inactive_users"
	    t.integer   "internal_one_week_inactive_users"
	    t.integer   "internal_one_month_inactive_users"
	    t.integer   "internal_daily_churn"
	    t.integer   "internal_weekly_churn"
	    t.integer   "internal_monthly_churn"

		  t.timestamps
		end
	end
end
