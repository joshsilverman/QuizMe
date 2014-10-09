class AddAnswerCountsToQuestion < ActiveRecord::Migration
  def change
    add_column :questions, :_answer_counts, :hstore
  end
end
