class AddAnswersToPublicationCache < ActiveRecord::Migration
  def up
    add_column :publications, :_answers, :hstore
  end

  def down
    remove_column :publications, :_answers, :hstore
  end
end
