class AddTypeIdToRelationships < ActiveRecord::Migration
  def change
    add_column :relationships, :type_id, :integer
  end
end
