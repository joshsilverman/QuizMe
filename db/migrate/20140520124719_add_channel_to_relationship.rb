class AddChannelToRelationship < ActiveRecord::Migration
  def up
    add_column :relationships, :channel, :integer

    Relationship.update_all channel: 0
  end

  def down
    remove_column :relationships, :channel
  end
end
