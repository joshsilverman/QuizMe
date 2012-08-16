class AddPostIdToPostqueue < ActiveRecord::Migration
  def change
  	remove_column :post_queues, :question_id
    add_column :post_queues, :post_id, :integer
  end
end
