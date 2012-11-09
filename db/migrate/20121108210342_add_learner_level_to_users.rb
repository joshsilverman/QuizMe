class AddLearnerLevelToUsers < ActiveRecord::Migration
  def change
    add_column :users, :learner_level, :string, :default => "unengaged"
    User.all.each_with_index do |user, i|
    	posts = user.posts.not_spam
    	if posts.where("correct is not null and posted_via_app = ? and interaction_type = 2", true).present?
    		level = "feed answer"
    	elsif posts.where("correct is not null and posted_via_app != ? and interaction_type = 2", true).present?
    		level = "twitter answer"
    	elsif posts.where("correct is not null and interaction_type = 4").present?
    		level = "DM answer"
    	elsif posts.where("correct is null and interaction_type = 2").present?
    		level = "mention"
    	elsif posts.where("interaction_type = 3").present?
    		level = "share"
    	elsif posts.where("interaction_type = 4").present?
    		level = "dm"
    	else
    		level = "unengaged"
    	end
    	puts "#{i}. #{user.twi_screen_name} - #{level}"
    	user.update_attribute(:learner_level, level)
    end
  end
end
