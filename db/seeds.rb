# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

# for account_id in 1..5
# 	for days in 0..30
# 		# Stat.create(:account_id => account_id,
# 		# 	:date => Date.today - 30 + days,
# 	 #    :followers => days*10 + rand(25),
# 	 #    :friends => days*50 + rand(25),
# 	 #    :rts => rand(20),
# 	 #    :mentions => 5 + rand(25),
# 	 #    :created_at => Date.today - 30 + days,
# 	 #    :updated_at => Date.today - 30 + days,
# 	 #    :twitter_posts => 8,
# 	 #    :tumblr_posts => 0,
# 	 #    :facebook_posts => 0,
# 	 #    :internal_posts => 8,
# 	 #    :twitter_answers => rand(5)*7,
# 	 #    :tumblr_answers => 0,
# 	 #    :facebook_answers => 0,
# 	 #    :internal_answers => rand(10)*7,
# 	 #    :twitter_daily_active_users => rand(50) + 2*days,
# 	 #    :twitter_weekly_active_users => rand(20) + 2*days,
# 	 #    :twitter_monthly_active_users => rand(10) + 2*days,
# 	 #    :twitter_one_day_inactive_users => rand(10) + days,
# 	 #    :twitter_one_week_inactive_users => rand(10) + days,
# 	 #    :twitter_one_month_inactive_users => rand(10) + days,
# 	 #    :twitter_daily_churn => rand(10) + days/2,
# 	 #    :twitter_weekly_churn => rand(10) + days/2,
# 	 #    :twitter_monthly_churn => rand(10) + days/2,
# 	 #    :internal_daily_active_users => rand(50) + 2*days,
# 	 #    :internal_weekly_active_users => rand(20) + 2*days,
# 	 #    :internal_monthly_active_users => rand(10) + 2*days,
# 	 #    :internal_one_day_inactive_users => rand(10) + days,
# 	 #    :internal_one_week_inactive_users => rand(10) + days,
# 	 #    :internal_one_month_inactive_users => rand(10) + days,
# 	 #    :internal_daily_churn => rand(10) + days/2,
# 	 #    :internal_weekly_churn => rand(10) + days/2,
# 	 #    :internal_monthly_churn => rand(10) + days/2)
# 	end
# end

for days in 0..30
	for i in 1..rand(10)+1
		p = [['twitter',['answer','retweet']], ['quizme',['answer']]].sample
		Engagement.create(:account_id => 1,
											:date => (Date.today - 30 + days).to_s,
											:user_id => i,
											:mention_id => 0,
											:provider => p[0],
											:engagement_type => p[1].sample)
	end
end