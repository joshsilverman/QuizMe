class AddAnswersToQuestion < ActiveRecord::Migration
  def change
    add_column :questions, :_answers, :hstore
  end
end
