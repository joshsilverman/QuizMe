class SetRespondedToDefaultInEngagements < ActiveRecord::Migration
  def change
  	remove_column :engagements, :responded_to
  	add_column :engagements, :responded_to, :boolean, :default => false
	end
end
