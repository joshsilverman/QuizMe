require "minitest_helper"

describe Asker do
	before :each do
		Rails.cache.clear
	end

	describe "reengages inactive users" do
		before :each do
			# admin = User.create # unnecessary
			

			asker = Asker.create
			user = User.create
			FactoryGirl.create(:post, user_id: user.id, created_at: Time.now - 1.5.days, in_reply_to_user_id: asker.id)
		end

		it "that responded" do
			Asker.reengage_inactive_users
		end

		it "reengages with correct asker"

		it "reengages with unanswered question"
	end

end