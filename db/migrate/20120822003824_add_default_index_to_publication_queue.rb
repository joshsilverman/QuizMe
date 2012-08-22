class AddDefaultIndexToPublicationQueue < ActiveRecord::Migration
  def up
  	remove_column :publication_queues, :index
  	add_column :publication_queues, :index, :integer, :default => 0
  end

  def down
  	remove_column :publication_queues, :index
  	add_column :publication_queues, :index, :integer
  end
end
