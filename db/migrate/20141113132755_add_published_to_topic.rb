class AddPublishedToTopic < ActiveRecord::Migration
  def change
    add_column :topics, :published, :bool
  end
end
