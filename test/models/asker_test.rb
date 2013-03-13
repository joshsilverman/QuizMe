require "minitest_helper"

describe Asker do

	describe "reengages inactive users" do
		before :each do
			# admin = User.create # unnecessary
			ADMINS = []

			asker = Asker.create
			user = User.create
			FactoryGirl.create(:post, user_id: user.id, created_at: Time.now - 1.5.days)
		end

		it "that responded" do
			
			Asker.reengage_inactive_users
		end
	end
end