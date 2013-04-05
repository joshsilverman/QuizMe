class CreateAskersRelatedAskers < ActiveRecord::Migration
  def change
    create_table :related_askers, id: false do |t|
      t.integer :asker_id
      t.integer :related_asker_id
    end
  
    add_index(:related_askers, [:asker_id, :related_asker_id], :unique => true)
    add_index(:related_askers, [:related_asker_id, :asker_id], :unique => true)
  end
end
