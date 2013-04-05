class CreateRelatedUsers < ActiveRecord::Migration
  def change
    create_table :related_users, id: false do |t|
      t.integer :user_id
      t.integer :related_user_id
    end
  
    add_index(:related_users, [:user_id, :related_user_id], :unique => true)
    add_index(:related_users, [:related_user_id, :user_id], :unique => true)
  end
end