class AddSearchTermTopicIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :search_term_topic_id, :integer
  end
end
