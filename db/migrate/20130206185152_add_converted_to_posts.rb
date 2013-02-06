class AddConvertedToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :converted, :boolean
  end
end
