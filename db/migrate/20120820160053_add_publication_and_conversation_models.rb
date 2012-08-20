class AddPublicationAndConversationModels < ActiveRecord::Migration
  def up
    create_table :publications do |t|
      t.integer :question_id
      t.integer :asker_id

      t.timestamps
    end

    create_table :conversations do |t|
      t.integer :publication_id
      t.integer :post_id
      t.integer :user_id

      t.timestamps
    end  

    add_column :posts, :is_parent, :boolean, :default => false  
    add_column :posts, :publication_id, :integer
    add_column :posts, :conversation_id, :integer
    add_column :publications, :publication_queue_id, :integer
    remove_column :post_queues, :post_id
    rename_table :post_queues, :publication_queues
  end

  def down
  	drop_table :publications
  	drop_table :conversations
  	remove_column :posts, :is_parent
    remove_column :posts, :publication_id
    remove_column :posts, :conversation_id
    rename_table :publication_queues, :post_queues
    add_column :post_queues, :post_id, :integer
  end
end