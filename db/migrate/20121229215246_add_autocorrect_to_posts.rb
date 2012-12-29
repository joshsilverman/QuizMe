class AddAutocorrectToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :autocorrect, :boolean
  end
end
