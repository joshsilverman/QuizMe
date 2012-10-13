class AddAuthorIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :author_id, :boolean
  end
end
