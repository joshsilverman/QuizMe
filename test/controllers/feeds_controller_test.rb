require 'minitest_helper'

describe FeedsController do

	before :each do
		@user = FactoryGirl.create(:user, twi_user_id: 1)
		login_as(@user, :scope => :user)

		@asker = FactoryGirl.create(:asker)
		@user = FactoryGirl.create(:user, twi_user_id: 1)
		@asker.followers << @user		

		@question = FactoryGirl.create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)		
		@publication = FactoryGirl.create(:publication, question: @question, asker: @asker)
		@question_status = FactoryGirl.create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)		
	end

	describe "show" do

		it "displays user activity after answer" do
			visit "/feeds/#{@asker.id}"
			page.find("#post_feed").visible?.must_equal true
		end
	end
end