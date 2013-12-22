class AddIndexInReplyToQuestionIdToPosts < ActiveRecord::Migration
  def change
    add_index :posts, :in_reply_to_question_id
  end
end
