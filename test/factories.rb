FactoryGirl.define do

	factory :user do
		role 'user'
    email 'joshs.silverman@gmail.com'
		password "password"
		twi_profile_img_url 'abc.jpg'
		twi_screen_name 'scottie p.'
		sequence(:twi_user_id) {|n| n}

		factory :admin do
      role 'admin'
    end

    factory :emailer do
    	communication_preference 2
    end
	end

	factory :moderator do
		role 'moderator'
		published true
		twi_profile_img_url 'abc.jpg'
		twi_screen_name 'leroy moderator'
	end	
	
	factory :asker do
		role 'asker'
		published true
		twi_profile_img_url 'abc.jpg'
		twi_screen_name 'QuizMeBio'
	end	

	factory :post do
		user_id 1
		spam false
		interaction_type 1
		text 'Leroy\'s my boy'

		factory :dm do
			interaction_type 4

			trait :initial_question_dm do
				intention 'initial question dm'
			end
		end
	end

	factory :question do
		text 'Where on the myosin does ATP bond to?'

	  after(:create) do |question|
	    create :correct_answer, question: question
	    create :incorrect_answer, question: question
	    create :incorrect_answer, question: question
	    create :incorrect_answer, question: question
	  end
	end

	factory :answer do
		text 'I am an answer'
		factory :correct_answer do
			correct true
			text 'the correct answer'
		end
		factory :incorrect_answer do
			correct false
			text ['red herring', 'not me', 'me me me... j/k', 'Im right, trust me'].sample
		end
	end	

	factory :publication do
		published true
	end

	factory :conversation do
	end

	factory :moderation do
		# type_id 1
	end

	factory :post_moderation do
		# type_id 1
	end

	factory :question_moderation do
		# type_id 1
	end	

	factory :topic do
		name 'great topic name!'

		factory :search_term do
			type_id 3
		end		
	end	
end