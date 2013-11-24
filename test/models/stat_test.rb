require 'test_helper'

describe Stat do	
	before :each do 
		Rails.cache.clear
	end

	describe 'calculates w-o-w weekly users' do
		before :each do
			@daus = [1,1,2,1,1,2,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,2,1,1,1,2,1,1,1,1]
			@waus = [9,9,9,9,9,9,8,8,8,8,7,7,7,7,7,8,8,8,8,9,9,9,8,8]
			@ratios = [-0.111, -0.111, -0.111, -0.222, -0.222, -0.222, -0.125, -0.125, 0.0, 0.0, 0.143, 0.143, 0.286, 0.286, 0.286, 0.0, 0.0]

			@daus.each do |count|
				count.times do
					user = create :user
					user.posts << (post = create(:post, interaction_type: 3))
				end
				Timecop.travel(Time.now + 1.day)
			end
		end

		it 'with correct daus' do
			calculated_daus = Stat.dau_ids_by_date.sort
			calculated_daus.map{|r|r[1].count}.must_equal @daus
		end

		it 'with correct waus' do
			calculated_waus = Stat.paus_by_date Stat.dau_ids_by_date, 7
			calculated_waus.sort.map{|e|e[1]}.must_equal @waus
		end

		describe 'with correct ratios' do
			it 'without repeat users' do
				calculated_ratios_rounded = Stat.pg_ratios.map{|r|(r[1]*1000.0).round/1000.0}
				calculated_ratios_rounded.must_equal @ratios
			end

			it 'with repeated users' do
				user = Post.last.user
				user.posts << create(:post, interaction_type: 3, created_at: 2.day.ago)
				calculated_ratios_rounded = Stat.pg_ratios.map{|r|(r[1]*1000.0).round/1000.0}
				calculated_ratios_rounded.last.must_equal @ratios.last
				calculated_ratios_rounded[-2].wont_equal @ratios[-2]
			end
		end
	end
end

describe Stat, '#graph_dau_mau' do
	it 'returns array' do
		data = Stat.graph_dau_mau 1
		data.must_be_kind_of Array
	end
end