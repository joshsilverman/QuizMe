class DropTableReps < ActiveRecord::Migration
  def up
    drop_table :reps
  end

  def down
    create_table :reps do |t|
      t.integer  :user_id
      t.integer  :post_id
      t.boolean  :correct
      t.datetime :created_at
      t.datetime :updated_at
      t.integer  :question_id
      t.integer  :publication_id
    end
  end
end