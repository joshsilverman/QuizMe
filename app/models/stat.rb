class Stat < ActiveRecord::Base
	belongs_to :account
	
	def self.collect_daily_stats_for(current_acct)
		d = Date.today
		last_post_id = current_acct.posts.where("updated_at > ? and provider = 'twitter' ", Time.now-1.days).first.provider_post_id.to_i
		today = Stat.find_or_create_by_date_and_account_id((d - 1.days).to_s, current_acct.id)
		client = current_acct.twitter
		yesterday = Stat.get_yesterday(current_acct.id)
		twi_account = client.user
		
		followers = twi_account.follower_count
		followers_delta = followers - yesterday.followers
		friends = twi_account.friend_count
		friends_delta = friends - yesterday.friends
		tweets = twi_account.tweet_count
		tweets_delta = tweets - yesterday.tweets
		rts_today = client.retweets_of_me({:count => 100, :since_id => last_post_id}).count
		rts = rts_today + yesterday.rts
		mentions_today = client.mentions({:count => 100, :since_id => last_post_id}).count
		mentions = mentions_today + yesterday.mentions
		today.questions_answered_today = 0
		questions_answered = today.questions_answered_today + yesterday.questions_answered
		
		active = Mention.where("created_at > ? and correct != null", d - 1.day).group(:user_id).count.map{|k,v| k}.to_set
		three_day = Mention.where("created_at > ? and correct != null", d - 8.days).group(:user_id).count.map{|k,v| k}.to_set
		one_week = Mention.where("created_at > ? and correct != null", d - 30.days).group(:user_id).count.map{|k,v| k}.to_set
		one_month = Mention.where("correct != null").group(:user_id).count.map{|k,v| k}.to_set
		unique_active_users = active.count
		three_day_inactive_users = (three_day - active).count
		one_week_inactive_users = (one_week - three_day - active).count
		one_month_plus_inactive_users = (one_month - one_week - three_day - active).count

		today.update_attributes(:followers => followers,
														:followers_delta => followers_delta,
														:friends => friends,
														:friends_delta => friends_delta,
														:tweets => tweets,
														:tweets_delta => tweets_delta,
														:rts => rts,
														:rts_today => rts_today,
														:mentions => mentions,
														:mentions_today => mentions_today,
														:questions_answered => questions_answered,
														:unique_active_users => unique_active_users,
														:three_day_inactive_users => three_day_inactive_users,
														:one_week_inactive_users => one_week_inactive_users,
														:one_month_plus_inactive_users => one_month_plus_inactive_users)
	end

	def self.get_yesterday(id)
		###get yesterdays stats or create dummy yesterday for math
		d = Date.today
		num_days_back = 2
		yesterday = Stat.find_by_date_and_account_id((d - num_days_back.days).to_s, id)
		while yesterday.nil? and num_days_back <= 8
			num_days_back += 1
			yesterday = Stat.find_by_date_and_account_id((d - num_days_back.days).to_s, id)
		end
		if yesterday.nil?
			yesterday = Stat.new
			yesterday.followers = 0
      yesterday.followers_delta = 0
      yesterday.friends = 0
      yesterday.friends_delta = 0
      yesterday.tweets = 0
      yesterday.tweets_delta = 0
      yesterday.rts = 0
      yesterday.rts_today = 0
      yesterday.mentions = 0
      yesterday.mentions_today = 0
      yesterday.questions_answered = 0
      yesterday.questions_answered_today = 0
      yesterday.unique_active_users = 0
      yesterday.three_day_inactive_users = 0
      yesterday.one_week_inactive_users = 0
      yesterday.one_month_plus_inactive_users = 0
		end
		yesterday
	end

	def self.get_all_retweets(days)
		rts = Stat.where('updated_at > ? and updated_at < ?', Date.today - days, Date.today)
		rts_json = {}
		rts.each do |rt|
			rts_json[rt.date]=0 if rts_json[rt.date].nil?
			rts_json[rt.date]+= rt.rts
		end
		rts_json
	end

	def self.get_all_dau(days)
		dau = Stat.where('updated_at > ? and updated_at < ?', Date.today - days, Date.today)
		puts dau
		dau_json = {}
		dau.each do |d|
			dau_json[d.date]=[0,0,0] if dau_json[d.date].nil?
			dau_json[d.date][0]+= d.twitter_daily_active_users
			dau_json[d.date][1]+= d.internal_daily_active_users
			dau_json[d.date][2]+= d.twitter_daily_active_users + d.internal_daily_active_users
		end
		puts dau_json
		dau_json
	end

	def self.get_all_questions_answered(days)
		questions = Stat.where('updated_at > ? and updated_at < ?', Date.today - days, Date.today)
		q_json = {}
		questions.each do |q|
			q_json[q.date]=[0,0,0] if q_json[q.date].nil?
			q_json[q.date][0]+= q.twitter_answers
			q_json[q.date][1]+= q.internal_answers
			q_json[q.date][2]+= q.twitter_answers + q.internal_answers
		end
		q_json
	end

	def self.get_all_headsup
		this_week = Stat.where('updated_at > ? and updated_at < ?', Date.today - 7, Date.today)
		last_week = Stat.where('updated_at > ? and updated_at < ?', Date.today - 14, Date.today - 7)
		tw = Stat.build_headsup_json(this_week)
		lw = Stat.build_headsup_json(last_week)
		headsup = {}
		tw.each do |k,v|
			headsup[k] = (v.nil? or lw[k].nil?) ? [nil, nil] : [v, (((v-lw[k])/lw[k].to_f)*100).round(2)]
		end
		headsup
	end

	def self.internal_retention(days, units)
		config = {'api_key' => '413bec33f14dd73948f749abfbec3df4',
			'api_secret' => '323f327138ee4227124f1480f8a1449e'}
		client = Mixpanel::Client.new(config)
		data = client.request do
		  resource       'retention'
			from_date      "#{Date.today - days}"
			to_date        "#{Date.today}"
			retention_type 'birth'
			born_event     'PageLoaded'
			born_where     '"review" in properties["url"]'
			unit           "#{units}"
			interval_count '10'
		end
		puts data
		data
	end

	def self.twitter_retention(days)

	end

	def self.build_headsup_json(weekly_stats)
		followers = 0
		tweets = 0
		questions_answered = 0
		dau = 0
		rts = 0
		return {} if weekly_stats.nil? or weekly_stats.empty?
		weekly_stats.each do |w|
			followers += w.followers
			tweets += w.twitter_posts
			questions_answered += w.twitter_answers
			questions_answered += w.internal_answers
			dau += w.internal_daily_active_users.nil? ? 0 : w.internal_daily_active_users
			rts += w.rts
		end
		headsup= {'followers' => followers,
							'tweets' => tweets,
							'questions_answered' => questions_answered,
							'average_daily_active_users' => (dau/7.0).round(2),
							'weekly_active_users' => weekly_stats.last.internal_weekly_active_users,
							'rts' => rts,
							'weekly_churn' => weekly_stats.last.internal_weekly_churn}
	end
end
