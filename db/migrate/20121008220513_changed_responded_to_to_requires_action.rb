class ChangedRespondedToToRequiresAction < ActiveRecord::Migration
  def up
  	Post.all.each do |p|
  		next if p.responded_to.nil?
  		p.update_attribute(:responded_to, !p.responded_to)
  	end  	  	
  	rename_column :posts, :responded_to, :requires_action
  end

  def down
  	Post.all.each do |p|
  		next if p.requires_action.nil?
  		p.update_attribute(:requires_action, !p.requires_action)
  	end  	
  	rename_column :posts, :requires_action, :responded_to
  end
end
