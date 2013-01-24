class CreateNudges < ActiveRecord::Migration
  def change
    create_table :nudges do |t|
      t.integer :asker_id
      t.integer :client_id
      t.string :url
      t.text :text

      t.timestamps
    end

    add_column :posts, :nudge_id, :integer
  end
end
