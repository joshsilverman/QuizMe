class DropTableRequirements < ActiveRecord::Migration
  def up
    drop_table :requirements
  end

  def down
    create_table :requirements do |t|
      t.integer :badge_id
      t.integer :question_id

      t.timestamps
    end
  end
end
