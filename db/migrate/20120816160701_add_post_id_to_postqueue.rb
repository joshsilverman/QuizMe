class AddPostIdToPostqueue < ActiveRecord::Migration
  def change
  	remove_column :postqueues, :question_id
    add_column :postqueues, :post_id, :integer
  end
end
