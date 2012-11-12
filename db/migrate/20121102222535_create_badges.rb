class CreateBadges < ActiveRecord::Migration
  def change
    create_table :badges do |t|
      t.integer :asker_id
      t.string :title
      t.string :filename
      t.text :description

      t.timestamps
    end
  end
end
