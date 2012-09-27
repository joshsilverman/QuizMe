class AddAutospamToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :autospam, :boolean
  end
end
