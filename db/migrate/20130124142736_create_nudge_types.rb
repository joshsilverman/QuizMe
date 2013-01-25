class CreateNudgeTypes < ActiveRecord::Migration
  def change
    create_table :nudge_types do |t|
      t.integer :client_id
      t.string :url
      t.text :text
      t.boolean :active, :default => false

      t.timestamps
    end

    add_column :posts, :nudge_type_id, :integer
  end
end
