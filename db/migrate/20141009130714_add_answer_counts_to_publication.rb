class AddAnswerCountsToPublication < ActiveRecord::Migration
  def change
    add_column :publications, :_answer_counts, :hstore
  end
end
