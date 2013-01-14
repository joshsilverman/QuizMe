class CreateTransitions < ActiveRecord::Migration
  def change
    create_table :transitions do |t|
      t.integer :from_segment
      t.integer :to_segment
      t.integer :segment_type
      t.integer :user_id
       	
      t.timestamps
    end
  end
end
