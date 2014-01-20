class AddIndexToUsersSujbect < ActiveRecord::Migration
  def change
    add_index :users, :subject
  end
end
