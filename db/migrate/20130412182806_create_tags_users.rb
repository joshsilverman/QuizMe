class CreateTagsUsers < ActiveRecord::Migration
  def change
    create_table :tags_users do |t|
      t.integer :user_id
      t.integer :tag_id
    end
  end
end
