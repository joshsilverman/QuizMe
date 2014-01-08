class AddColumnCacheToPublication < ActiveRecord::Migration
  def change
    add_column :publications, :_cache, :hstore
  end
end
