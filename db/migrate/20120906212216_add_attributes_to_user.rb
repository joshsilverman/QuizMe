class AddAttributesToUser < ActiveRecord::Migration
  def change
    add_column :users, :new_user_q_id, :integer
    add_column :users, :bg_image, :string
  end
end
