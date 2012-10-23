class AddIntentionToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :intention, :string
  end
end
