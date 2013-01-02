class AddIndices < ActiveRecord::Migration
  def change
    add_index :answers, ["question_id"]
    add_index :askertopics, ["asker_id","topic_id"]
    add_index :askertopics, ["topic_id"]
    add_index :askertopics, ["asker_id"]
    add_index :conversations, ["publication_id"]
    add_index :conversations, ["post_id"]
    add_index :conversations, ["user_id"]

    add_index :posts, ["user_id"]
    add_index :posts, ["provider_post_id"]
    add_index :posts, ["in_reply_to_post_id"]
    add_index :posts, ["publication_id"]
    add_index :posts, ["conversation_id"]
    add_index :posts, ["in_reply_to_user_id"]
    add_index :posts, ["interaction_type"]
    add_index :posts, ["created_at"]
    
    add_index :publications, ["question_id"]
    add_index :publications, ["asker_id"]
    add_index :publications, ["published"]

    add_index :questions, ["topic_id"]
    add_index :questions, ["user_id"]
    add_index :questions, ["created_for_asker_id"]

    add_index :users, ["new_user_q_id"]
    add_index :users, ["published"]
    add_index :users, ["author_id"]
    add_index :users, ["learner_level"]
    add_index :users, ["client_id"]
    add_index :users, ["rate_sheet_id"]
  end
end
