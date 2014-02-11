class AddAskerCacheToPublication < ActiveRecord::Migration
  def up
    add_column :publications, :_asker, :hstore
  end

  def down
    remove_column :publications, :_asker, :hstore
  end
end
