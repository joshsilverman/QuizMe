class EditStatsSavedInStats < ActiveRecord::Migration
  def up
    remove_column :stats, :followers_delta
    remove_column :stats, :friends_delta
    remove_column :stats, :tweets
    remove_column :stats, :tweets_delta
    remove_column :stats, :rts_today
    remove_column :stats, :mentions_today
    remove_column :stats, :questions_answered_today
    remove_column :stats, :questions_answered
    remove_column :stats, :unique_active_users
    remove_column :stats, :three_day_inactive_users
    remove_column :stats, :one_month_plus_inactive_users

    add_column :stats, :twitter_posts, :integer, :default => 0
    add_column :stats, :tumblr_posts, :integer, :default => 0
    add_column :stats, :facebook_posts, :integer, :default => 0
    add_column :stats, :internal_posts, :integer, :default => 0
    add_column :stats, :twitter_answers, :integer, :default => 0
    add_column :stats, :tumblr_answers, :integer, :default => 0
    add_column :stats, :facebook_answers, :integer, :default => 0
    add_column :stats, :internal_answers, :integer, :default => 0
    add_column :stats, :twitter_daily_active_users, :integer
    add_column :stats, :twitter_weekly_active_users, :integer
    add_column :stats, :twitter_monthly_active_users, :integer
    add_column :stats, :twitter_one_day_inactive_users, :integer
    add_column :stats, :twitter_one_week_inactive_users, :integer
    add_column :stats, :twitter_one_month_inactive_users, :integer
    add_column :stats, :twitter_daily_churn, :integer
    add_column :stats, :twitter_weekly_churn, :integer
    add_column :stats, :twitter_monthly_churn, :integer
    add_column :stats, :internal_daily_active_users, :integer
    add_column :stats, :internal_weekly_active_users, :integer
    add_column :stats, :internal_monthly_active_users, :integer
    add_column :stats, :internal_one_day_inactive_users, :integer
    add_column :stats, :internal_one_week_inactive_users, :integer
    add_column :stats, :internal_one_month_inactive_users, :integer
    add_column :stats, :internal_daily_churn, :integer
    add_column :stats, :internal_weekly_churn, :integer
    add_column :stats, :internal_monthly_churn, :integer
  end

  def down
    add_column :stats, :followers_delta, :integer
    add_column :stats, :friends_delta, :integer
    add_column :stats, :tweets, :integer
    add_column :stats, :tweets_delta, :integer
    add_column :stats, :rts_today, :integer
    add_column :stats, :mentions_today, :integer
    add_column :stats, :questions_answered_today, :integer
    add_column :stats, :questions_answered, :integer
    add_column :stats, :unique_active_users, :integer
    add_column :stats, :three_day_inactive_users, :integer
    add_column :stats, :one_month_plus_inactive_users, :integer

    remove_column :stats, :twitter_posts
    remove_column :stats, :tumblr_posts
    remove_column :stats, :facebook_posts
    remove_column :stats, :internal_posts
    remove_column :stats, :twitter_answers
    remove_column :stats, :tumblr_answers
    remove_column :stats, :facebook_answers
    remove_column :stats, :internal_answers
    remove_column :stats, :twitter_daily_active_users
    remove_column :stats, :twitter_weekly_active_users
    remove_column :stats, :twitter_monthly_active_users
    remove_column :stats, :twitter_one_day_inactive_users
    remove_column :stats, :twitter_one_week_inactive_users
    remove_column :stats, :twitter_one_month_inactive_users
    remove_column :stats, :twitter_daily_churn
    remove_column :stats, :twitter_weekly_churn
    remove_column :stats, :twitter_monthly_churn
    remove_column :stats, :internal_daily_active_users
    remove_column :stats, :internal_weekly_active_users
    remove_column :stats, :internal_monthly_active_users
    remove_column :stats, :internal_one_day_inactive_users
    remove_column :stats, :internal_one_week_inactive_users
    remove_column :stats, :internal_one_month_inactive_users
    remove_column :stats, :internal_daily_churn
    remove_column :stats, :internal_weekly_churn
    remove_column :stats, :internal_monthly_churn
  end
end