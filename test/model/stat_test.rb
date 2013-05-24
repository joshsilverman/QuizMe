require 'minitest_helper'

describe Stat do	
	before :each do 
		Rails.cache.clear
	end

	describe 'calculates w-o-w weekly users' do
		before :each do
			daus = [1,5,1,1,6,1,6,1,4,5,9,2,6,7,6,7,9,6,8,9,9,13,13,14,15,11,15,16,21,23]
			daus.each do |count|
				count.times do
					user = FactoryGirl.create :user
					user.posts << FactoryGirl.create(:post)
				end
				Timecop.travel(Time.now + 1.day)
			end
		end

		it 'with correct daus' do
			puts stat.pg_daily
		end

		it 'with correct waus'
		# waus = [nil,nil,nil,nil,nil,nil,nil,21,21,20,24,32,28,33,34,39,42,46,43,49,52,54,61,67,72,81,84,90,97,105,115]
		it 'with correct ratios'
	end
end