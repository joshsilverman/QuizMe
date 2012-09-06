# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

a = User.asker(14)

for i in 1..5
	q = Question.find_or_create_by_text_and_created_for_asker_id("Fake question number #{i}", a.id)
	if q.answers.blank?
		t = Answer.create(:question_id => q.id, :text => 'True', :correct => true)
		f = Answer.create(:question_id => q.id, :text => 'False', :correct => false)
		pub = Publication.create(:question_id => q.id, :published => true, :asker_id => a.id)
		p = Post.create( 
	      :provider_post_id => nil,
	      :engagement_type => nil,
	      :text => q.text,
	      :provider => 'twitter',
	      :user_id => a.id,
	      :in_reply_to_post_id => nil, #reply_post ? reply_post.id : nil,
	      :in_reply_to_user_id => nil, #a.id,
	      :conversation_id => nil, #conversation.nil? ? nil : conversation.id,
	      :posted_via_app => true
	    )
	    Post.create(:provider_post_id => nil,
	      :engagement_type => nil,
	      :text => "Answer #{i}",
	      :provider => 'twitter',
	      :user_id => 10,
	      :in_reply_to_post_id => p.id, #reply_post ? reply_post.id : nil,
	      :in_reply_to_user_id => a.id,
	      :conversation_id => nil, #conversation.nil? ? nil : conversation.id,
	      :posted_via_app => false)
	end
end

Post.create(:provider_post_id => nil,
	      :engagement_type => nil,
	      :text => "Rando Post",
	      :provider => 'twitter',
	      :user_id => 6,
	      :in_reply_to_post_id => nil, #reply_post ? reply_post.id : nil,
	      :in_reply_to_user_id => a.id,
	      :conversation_id => nil, #conversation.nil? ? nil : conversation.id,
	      :posted_via_app => false)
