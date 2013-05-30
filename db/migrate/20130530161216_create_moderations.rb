class CreateModerations < ActiveRecord::Migration
  def change
    create_table :moderations do |t|
      t.integer :post_id
      t.integer :user_id
      t.integer :type_id
      t.boolean :accepted

      t.timestamps
    end
  end
end
