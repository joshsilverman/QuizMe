FactoryGirl.define do
	factory :asker do
		role 'asker'
		published true
	end

	factory :user do
		role 'user'
	end

	factory :post do
		user_id 1
		spam false
		interaction_type 1
	end

	factory :question do
		text 'Whats up?'
	end

	factory :publication do
	end
end