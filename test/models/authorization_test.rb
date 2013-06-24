require 'minitest_helper'

describe Authorization do	
	before :each do 
		Rails.cache.clear
		@user = create(:user, twi_user_id: 1)
	end

	describe 'by token authentication' do
		describe 'logs user in' do
			it 'to proper page'
			it 'unless no token authentication information passed'
			it 'unless no user with authentication token found'
			it 'unless no expiration time found'
		end
	end
end