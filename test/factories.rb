FactoryGirl.define do

	factory :user do
		role 'user'
		email "a@a.com"
		password "password"
		twi_profile_img_url 'abc.jpg'
		twi_screen_name 'scottie p.'
		sequence(:twi_user_id) {|n| n}

		factory :admin do
      role 'admin'
    end

	end

	factory :asker do
		role 'moderator'
		published true
		twi_profile_img_url 'abc.jpg'
		twi_screen_name 'leroy asker'
	end	
	
	factory :asker do
		role 'asker'
		published true
		twi_profile_img_url 'abc.jpg'
		twi_screen_name 'leroy asker'
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
		text 'I am an answer'
		factory :correct_answer do
			correct true
		end
		factory :incorrect_answer do
			correct false
		end
	end	

	factory :publication do
		published true
	end

	factory :conversation do
	end

	factory :moderation do
		type_id 1
	end
end