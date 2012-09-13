class AddClickThroughsToStats < ActiveRecord::Migration
  def change
    add_column :stats, :click_throughs, :integer
  end
end
