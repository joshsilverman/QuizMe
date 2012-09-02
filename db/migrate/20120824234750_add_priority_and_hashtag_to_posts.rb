class AddPriorityAndHashtagToPosts < ActiveRecord::Migration
  def change
    add_column :questions, :priority, :boolean, :default => false
    add_column :questions, :hashtag, :string
  end
end
