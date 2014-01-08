class AlterPublicationCache < ActiveRecord::Migration
  def up
    remove_column :publications, :_cache, :hstore

    add_column :publications, :_question, :hstore
    add_column :publications, :_activity, :hstore
  end

  def down
    remove_column :publications, :_question, :hstore
    remove_column :publications, :_activity, :hstore
    
    add_column :publications, :_cache, :hstore
  end
end
