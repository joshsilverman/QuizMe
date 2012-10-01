class AddTypeAndCorrectToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :interaction_type, :integer
    add_column :posts, :correct, :boolean
  end
end
