FactoryGirl.define do
	factory :asker do
		role 'asker'
		published true
		twi_profile_img_url 'abc.jpg'
		twi_screen_name 'leroy j.'
	end

	factory :user do
		role 'user'
		email "a@a.com"
		password "password"
		twi_profile_img_url 'abc.jpg'
		twi_screen_name 'scottie p.'
	end

	factory :post do
		user_id 1
		spam false
		interaction_type 1
		text 'Leroy\'s my boy'
	end

	factory :question do
		text 'Whats up?'
	end

	factory :answer do
	end	

	factory :publication do
	end

	factory :conversation do
	end

	factory :moderation do
		type_id 1
	end
end