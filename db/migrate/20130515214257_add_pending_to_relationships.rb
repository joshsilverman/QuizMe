class AddPendingToRelationships < ActiveRecord::Migration
  def change
    add_column :relationships, :pending, :boolean, :default => true
  end
end
