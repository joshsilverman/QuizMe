class AddClickThroughsToStats < ActiveRecord::Migration
  def change
    add_column :stats, :click_throughs, :integer, :default => 0
  end
end
