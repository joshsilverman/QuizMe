class AddInReplyToQuestionIdToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :in_reply_to_question_id, :integer
  end
end
