class AddActiveToModerations < ActiveRecord::Migration
  def change
    add_column :moderations, :active, :boolean, default: true
  end
end
