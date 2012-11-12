class CreateRequirements < ActiveRecord::Migration
  def change
    create_table :requirements do |t|
      t.integer :badge_id
      t.integer :question_id

      t.timestamps
    end
  end
end
