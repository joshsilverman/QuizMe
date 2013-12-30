class AddColumnAskerIdToIssuances < ActiveRecord::Migration
  def change
    add_column :issuances, :asker_id, :integer
  end
end
