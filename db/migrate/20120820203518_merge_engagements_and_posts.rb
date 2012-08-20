class MergeEngagementsAndPosts < ActiveRecord::Migration
  def up
  	remove_column :posts, :queue_id
  	remove_column :posts, :question_id
  	remove_column :posts, :is_parent
  	remove_column :posts, :url
  	remove_column :posts, :link_type
  	remove_column :posts, :to_twi_user_id, :integer


  	rename_column :posts, :parent_id, :in_reply_to_post_id
  	rename_column :posts, :post_type, :engagement_type
  	rename_column :posts, :asker_id, :user_id

  	add_column :posts, :responded_to, :boolean, :default => false
  	add_column :posts, :in_reply_to_user_id, :integer 
  	add_column :posts, :posted_via_app, :boolean
  end

  def down
  	add_column :posts, :queue_id, :integer
  	add_column :posts, :question_id, :integer
  	add_column :posts, :is_parent, :boolean
  	add_column :posts, :url, :string
  	add_column :posts, :link_type, :string
  	add_column :posts, :to_twi_user_id, :integer


  	rename_column :posts, :in_reply_to_post_id, :parent_id
  	rename_column :posts, :engagement_type, :post_type
  	rename_column :posts, :user_id, :asker_id

  	remove_column :posts, :responded_to
  	remove_column :posts, :in_reply_to_user_id
  	remove_column :posts, :posted_via_app
  end
end
