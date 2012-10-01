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

ActiveRecord::Schema.define(:version => 20120928184119) do

  create_table "alternatives", :force => true do |t|
    t.integer "experiment_id"
    t.string  "content"
    t.string  "lookup",        :limit => 32
    t.integer "weight",                      :default => 1
    t.integer "participants",                :default => 0
    t.integer "conversions",                 :default => 0
  end

  add_index "alternatives", ["experiment_id"], :name => "index_alternatives_on_experiment_id"
  add_index "alternatives", ["lookup"], :name => "index_alternatives_on_lookup"

  create_table "answers", :force => true do |t|
    t.boolean   "correct"
    t.integer   "question_id"
    t.text      "text"
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

  create_table "askertopics", :force => true do |t|
    t.integer   "asker_id"
    t.integer   "topic_id"
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

  create_table "conversations", :force => true do |t|
    t.integer   "publication_id"
    t.integer   "post_id"
    t.integer   "user_id"
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

  create_table "experiments", :force => true do |t|
    t.string   "test_name"
    t.string   "status"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "experiments", ["test_name"], :name => "index_experiments_on_test_name"

  create_table "posts", :force => true do |t|
    t.integer   "user_id"
    t.string    "provider"
    t.text      "text"
    t.string    "engagement_type"
    t.string    "provider_post_id"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.integer   "in_reply_to_post_id"
    t.integer   "publication_id"
    t.integer   "conversation_id"
    t.boolean   "responded_to",        :default => false
    t.integer   "in_reply_to_user_id"
    t.boolean   "posted_via_app"
    t.string    "url"
    t.boolean   "spam"
    t.boolean   "autospam"
    t.integer   "interaction_type"
    t.boolean   "correct"
  end

  create_table "publication_queues", :force => true do |t|
    t.integer   "asker_id"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.integer   "index",      :default => 0
  end

  create_table "publications", :force => true do |t|
    t.integer   "question_id"
    t.integer   "asker_id"
    t.string    "url"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.integer   "publication_queue_id"
    t.boolean   "published",            :default => false
  end

  create_table "questions", :force => true do |t|
    t.text      "text"
    t.integer   "topic_id"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.integer   "user_id"
    t.integer   "status",               :default => 0
    t.integer   "created_for_asker_id"
    t.boolean   "priority",             :default => false
    t.string    "hashtag"
    t.integer   "seeder_id"
    t.text      "resource_url"
  end

  create_table "reps", :force => true do |t|
    t.integer   "user_id"
    t.integer   "post_id"
    t.boolean   "correct"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.integer   "question_id"
    t.integer   "publication_id"
  end

  create_table "stats", :force => true do |t|
    t.date      "date"
    t.integer   "followers",          :default => 0
    t.integer   "total_followers",    :default => 0
    t.integer   "retweets",           :default => 0
    t.integer   "mentions",           :default => 0
    t.integer   "questions_answered", :default => 0
    t.integer   "internal_answers",   :default => 0
    t.integer   "twitter_answers",    :default => 0
    t.integer   "active_users",       :default => 0
    t.text      "active_user_ids",    :default => ""
    t.integer   "asker_id"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.integer   "click_throughs",     :default => 0
  end

  create_table "topics", :force => true do |t|
    t.string    "name"
    t.timestamp "created_at"
    t.timestamp "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string    "twi_name"
    t.string    "twi_screen_name"
    t.integer   "twi_user_id"
    t.text      "twi_profile_img_url"
    t.string    "twi_oauth_token"
    t.string    "twi_oauth_secret"
    t.timestamp "created_at"
    t.timestamp "updated_at"
    t.string    "role",                :default => "user"
    t.string    "name"
    t.integer   "fb_user_id"
    t.string    "fb_oauth_token"
    t.string    "fb_oauth_secret"
    t.integer   "tum_user_id"
    t.string    "tum_oauth_token"
    t.string    "tum_oauth_secret"
    t.string    "tum_url"
    t.integer   "posts_per_day"
    t.text      "description"
    t.integer   "new_user_q_id"
    t.string    "bg_image"
  end

end
