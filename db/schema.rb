# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120822003824) do

  create_table "answers", :force => true do |t|
    t.boolean  "correct"
    t.integer  "question_id"
    t.text     "text"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "askertopics", :force => true do |t|
    t.integer  "asker_id"
    t.integer  "topic_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "conversations", :force => true do |t|
    t.integer  "publication_id"
    t.integer  "post_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "posts", :force => true do |t|
    t.integer  "user_id"
    t.string   "provider"
    t.text     "text"
    t.string   "engagement_type"
    t.string   "provider_post_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "in_reply_to_post_id"
    t.integer  "publication_id"
    t.integer  "conversation_id"
    t.boolean  "responded_to",        :default => false
    t.integer  "in_reply_to_user_id"
    t.boolean  "posted_via_app"
  end

  create_table "publication_queues", :force => true do |t|
    t.integer  "asker_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "index",      :default => 0
  end

  create_table "publications", :force => true do |t|
    t.integer  "question_id"
    t.integer  "asker_id"
    t.string   "url"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "publication_queue_id"
    t.boolean  "published",            :default => false
  end

  create_table "questions", :force => true do |t|
    t.text     "text"
    t.integer  "topic_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "status",               :default => 0
    t.integer  "created_for_asker_id"
  end

  create_table "reps", :force => true do |t|
    t.integer  "user_id"
    t.integer  "post_id"
    t.boolean  "correct"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "question_id"
    t.integer  "publication_id"
  end

  create_table "stats", :force => true do |t|
    t.string   "date"
    t.integer  "followers"
    t.integer  "friends"
    t.integer  "rts"
    t.integer  "mentions"
    t.integer  "one_week_inactive_users"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "asker_id"
    t.integer  "twitter_posts",                     :default => 0
    t.integer  "tumblr_posts",                      :default => 0
    t.integer  "facebook_posts",                    :default => 0
    t.integer  "internal_posts",                    :default => 0
    t.integer  "twitter_answers",                   :default => 0
    t.integer  "tumblr_answers",                    :default => 0
    t.integer  "facebook_answers",                  :default => 0
    t.integer  "internal_answers",                  :default => 0
    t.integer  "twitter_daily_active_users"
    t.integer  "twitter_weekly_active_users"
    t.integer  "twitter_monthly_active_users"
    t.integer  "twitter_one_day_inactive_users"
    t.integer  "twitter_one_week_inactive_users"
    t.integer  "twitter_one_month_inactive_users"
    t.integer  "twitter_daily_churn"
    t.integer  "twitter_weekly_churn"
    t.integer  "twitter_monthly_churn"
    t.integer  "internal_daily_active_users"
    t.integer  "internal_weekly_active_users"
    t.integer  "internal_monthly_active_users"
    t.integer  "internal_one_day_inactive_users"
    t.integer  "internal_one_week_inactive_users"
    t.integer  "internal_one_month_inactive_users"
    t.integer  "internal_daily_churn"
    t.integer  "internal_weekly_churn"
    t.integer  "internal_monthly_churn"
  end

  create_table "topics", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "twi_name"
    t.string   "twi_screen_name"
    t.integer  "twi_user_id"
    t.text     "twi_profile_img_url"
    t.string   "twi_oauth_token"
    t.string   "twi_oauth_secret"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "role",                :default => "user"
    t.string   "name"
    t.integer  "fb_user_id"
    t.string   "fb_oauth_token"
    t.string   "fb_oauth_secret"
    t.integer  "tum_user_id"
    t.string   "tum_oauth_token"
    t.string   "tum_oauth_secret"
    t.string   "tum_url"
    t.integer  "posts_per_day"
    t.text     "description"
  end

end
