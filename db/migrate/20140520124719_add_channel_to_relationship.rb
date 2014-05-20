class AddChannelToRelationship < ActiveRecord::Migration
  def change
    add_column :relationships, :channel, :integer
  end
end
