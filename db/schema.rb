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

ActiveRecord::Schema.define(:version => 20130405213038) do

  create_table "answers", :force => true do |t|
    t.boolean  "correct"
    t.integer  "question_id"
    t.text     "text"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "answers", ["question_id"], :name => "index_answers_on_question_id"

  create_table "askertopics", :force => true do |t|
    t.integer  "asker_id"
    t.integer  "topic_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "askertopics", ["asker_id", "topic_id"], :name => "index_askertopics_on_asker_id_and_topic_id"
  add_index "askertopics", ["asker_id"], :name => "index_askertopics_on_asker_id"
  add_index "askertopics", ["topic_id"], :name => "index_askertopics_on_topic_id"

  create_table "authorizations", :force => true do |t|
    t.integer  "user_id"
    t.string   "provider"
    t.string   "uid"
    t.string   "name"
    t.string   "email"
    t.string   "token"
    t.string   "secret"
    t.string   "link"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "badges", :force => true do |t|
    t.integer  "asker_id"
    t.string   "title"
    t.string   "filename"
    t.text     "description"
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

  add_index "conversations", ["post_id"], :name => "index_conversations_on_post_id"
  add_index "conversations", ["publication_id"], :name => "index_conversations_on_publication_id"
  add_index "conversations", ["user_id"], :name => "index_conversations_on_user_id"

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "exams", :force => true do |t|
    t.integer  "user_id"
    t.string   "subject"
    t.datetime "date"
    t.datetime "created_at",                                   :null => false
    t.datetime "updated_at",                                   :null => false
    t.integer  "question_count"
    t.decimal  "price",          :precision => 8, :scale => 2
  end

  create_table "issuances", :force => true do |t|
    t.integer  "user_id"
    t.integer  "badge_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "nudge_types", :force => true do |t|
    t.integer  "client_id"
    t.string   "url"
    t.text     "text"
    t.boolean  "active",     :default => false
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.boolean  "automatic",  :default => false
  end

  create_table "posts", :force => true do |t|
    t.integer  "user_id"
    t.string   "provider"
    t.text     "text"
    t.string   "provider_post_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "in_reply_to_post_id"
    t.integer  "publication_id"
    t.integer  "conversation_id"
    t.boolean  "requires_action",         :default => false
    t.integer  "in_reply_to_user_id"
    t.boolean  "posted_via_app"
    t.string   "url"
    t.boolean  "spam"
    t.boolean  "autospam"
    t.integer  "interaction_type"
    t.boolean  "correct"
    t.string   "intention"
    t.boolean  "autocorrect"
    t.integer  "nudge_type_id"
    t.integer  "in_reply_to_question_id"
    t.boolean  "converted"
    t.integer  "question_id"
  end

  add_index "posts", ["conversation_id"], :name => "index_posts_on_conversation_id"
  add_index "posts", ["created_at"], :name => "index_posts_on_created_at"
  add_index "posts", ["in_reply_to_post_id"], :name => "index_posts_on_in_reply_to_post_id"
  add_index "posts", ["in_reply_to_user_id"], :name => "index_posts_on_in_reply_to_user_id"
  add_index "posts", ["interaction_type"], :name => "index_posts_on_interaction_type"
  add_index "posts", ["provider_post_id"], :name => "index_posts_on_provider_post_id"
  add_index "posts", ["publication_id"], :name => "index_posts_on_publication_id"
  add_index "posts", ["user_id"], :name => "index_posts_on_user_id"

  create_table "posts_tags", :force => true do |t|
    t.integer  "post_id"
    t.integer  "tag_id"
    t.datetime "created_at"
    t.datetime "updated_at"
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

  add_index "publications", ["asker_id"], :name => "index_publications_on_asker_id"
  add_index "publications", ["published"], :name => "index_publications_on_published"
  add_index "publications", ["question_id"], :name => "index_publications_on_question_id"

  create_table "questions", :force => true do |t|
    t.text     "text"
    t.integer  "topic_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.integer  "status",               :default => 0
    t.integer  "created_for_asker_id"
    t.boolean  "priority",             :default => false
    t.string   "hashtag"
    t.integer  "seeder_id"
    t.text     "resource_url"
    t.string   "slug"
    t.string   "hint"
  end

  add_index "questions", ["created_for_asker_id"], :name => "index_questions_on_created_for_asker_id"
  add_index "questions", ["topic_id"], :name => "index_questions_on_topic_id"
  add_index "questions", ["user_id"], :name => "index_questions_on_user_id"

  create_table "rate_sheets", :force => true do |t|
    t.float    "tweet"
    t.float    "retweet"
    t.float    "lead"
    t.float    "conversion"
    t.string   "title"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "logo_image"
    t.float    "monthly_cap"
  end

  create_table "related_askers", :id => false, :force => true do |t|
    t.integer "asker_id"
    t.integer "related_asker_id"
  end

  add_index "related_askers", ["asker_id", "related_asker_id"], :name => "index_related_askers_on_asker_id_and_related_asker_id", :unique => true
  add_index "related_askers", ["related_asker_id", "asker_id"], :name => "index_related_askers_on_related_asker_id_and_asker_id", :unique => true

  create_table "related_users", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "related_user_id"
  end

  add_index "related_users", ["related_user_id", "user_id"], :name => "index_related_users_on_related_user_id_and_user_id", :unique => true
  add_index "related_users", ["user_id", "related_user_id"], :name => "index_related_users_on_user_id_and_related_user_id", :unique => true

  create_table "relationships", :force => true do |t|
    t.integer  "follower_id"
    t.integer  "followed_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "relationships", ["followed_id"], :name => "index_relationships_on_followed_id"
  add_index "relationships", ["follower_id", "followed_id"], :name => "index_relationships_on_follower_id_and_followed_id", :unique => true
  add_index "relationships", ["follower_id"], :name => "index_relationships_on_follower_id"

  create_table "reps", :force => true do |t|
    t.integer  "user_id"
    t.integer  "post_id"
    t.boolean  "correct"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "question_id"
    t.integer  "publication_id"
  end

  create_table "requirements", :force => true do |t|
    t.integer  "badge_id"
    t.integer  "question_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "stats", :force => true do |t|
    t.date     "date"
    t.integer  "followers",          :default => 0
    t.integer  "total_followers",    :default => 0
    t.integer  "retweets",           :default => 0
    t.integer  "mentions",           :default => 0
    t.integer  "questions_answered", :default => 0
    t.integer  "internal_answers",   :default => 0
    t.integer  "twitter_answers",    :default => 0
    t.integer  "active_users",       :default => 0
    t.text     "active_user_ids",    :default => ""
    t.integer  "asker_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "click_throughs",     :default => 0
  end

  create_table "tags", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "topics", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "transitions", :force => true do |t|
    t.integer  "from_segment"
    t.integer  "to_segment"
    t.integer  "segment_type"
    t.integer  "user_id"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
    t.string   "comment"
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
    t.string   "role",                   :default => "user"
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
    t.integer  "new_user_q_id"
    t.string   "bg_image"
    t.boolean  "published"
    t.integer  "author_id"
    t.string   "learner_level",          :default => "unengaged"
    t.datetime "last_interaction_at"
    t.datetime "last_answer_at"
    t.integer  "client_id"
    t.integer  "rate_sheet_id"
    t.boolean  "client_nudge"
    t.integer  "lifecycle_segment"
    t.integer  "activity_segment"
    t.integer  "interaction_segment"
    t.integer  "author_segment"
    t.string   "email"
    t.string   "encrypted_password",     :default => "",          :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
  end

  add_index "users", ["author_id"], :name => "index_users_on_author_id"
  add_index "users", ["client_id"], :name => "index_users_on_client_id"
  add_index "users", ["learner_level"], :name => "index_users_on_learner_level"
  add_index "users", ["new_user_q_id"], :name => "index_users_on_new_user_q_id"
  add_index "users", ["published"], :name => "index_users_on_published"
  add_index "users", ["rate_sheet_id"], :name => "index_users_on_rate_sheet_id"
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

end
