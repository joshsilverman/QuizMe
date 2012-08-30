class Stat < ActiveRecord::Base
	belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'
	
	def self.save_daily_stats_for_asker(current_acct)
		d = Date.today
		y = d - 1
		this_week_ary_of_days = []
		this_month_ary_of_days = []
		last_week_ary_of_days = []
		last_month_ary_of_days = []


		for i in 1..60
			this_week_ary_of_days << (d-i).to_s if i < 8
			this_month_ary_of_days << (d-i).to_s if i < 31
			last_week_ary_of_days << (d-i).to_s if i > 7 and i < 15
			last_month_ary_of_days << (d-i).to_s if i > 30
		end

		this_week_ary_of_days.sort!
		this_month_ary_of_days.sort!
		last_week_ary_of_days.sort!
		last_month_ary_of_days.sort!

		puts this_week_ary_of_days


		last_post = current_acct.posts.where("updated_at > ? and updated_at < ? and provider = 'twitter' ", Date.today-2, Date.today).first
		today_stat = Stat.find_or_create_by_date_and_asker_id(y.to_s, current_acct.id)
		yesterday_stat = Stat.get_yesterday(current_acct.id)
		client = current_acct.twitter
		twi_account = client.user

		##get all the stats
		#Total followers
		followers = twi_account.follower_count
		friends = twi_account.friend_count
		rts = last_post.nil? ? 0 : client.retweets_of_me({:count => 100, :since_id => last_post.provider_post_id.to_i}).count 
		mentions = last_post.nil? ? 0 : client.mentions({:count => 100, :since_id => last_post.provider_post_id.to_i}).count
		twitter_posts = current_acct.posts.select(:question_id).where("updated_at > ? and updated_at < ? and provider = 'twitter' and post_type = 'status' and link_type like 'initial%'", y, d).collect(&:question_id).to_set.count
		internal_posts = current_acct.posts.select(:question_id).where("updated_at > ? and updated_at < ? and provider = 'app'", y, d).collect(&:question_id).to_set.count
		facebook_posts = current_acct.posts.select(:question_id).where("updated_at > ? and updated_at < ? and provider = 'facebook'", y, d).collect(&:question_id).to_set.count
		tumblr_posts = current_acct.posts.select(:question_id).where("updated_at > ? and updated_at < ? and provider = 'tumblr'", y, d).collect(&:question_id).to_set.count
		
		twitter_answers = current_acct.posts.twitter_answers.where(:date => y.to_s).count
		internal_answers = current_acct.posts.internal_answers.where(:date => y.to_s).count
		facebook_answers = current_acct.posts.facebook_answers.where(:date => y.to_s).count
		tumblr_answers = current_acct.posts.tumblr_answers.where(:date => y.to_s).count
		
		twitter_daily_active_users = Post.twitter_answers.where(:date => y.to_s).collect(&:user_id)
		twitter_weekly_active_users = Post.twitter_answers.where(:date => this_week_ary_of_days).collect(&:user_id)
		twitter_monthly_active_users = Post.twitter_answers.where(:date => this_month_ary_of_days).collect(&:user_id)
		twitter_yesterday_active_users = Post.twitter_answers.where(:date => (y-1).to_s).collect(&:user_id)
		twitter_last_week_active_users = Post.twitter_answers.where(:date => last_week_ary_of_days).collect(&:user_id)
		twitter_last_month_active_users = Post.twitter_answers.where(:date => last_month_ary_of_days).collect(&:user_id)
		twitter_one_day_inactive_users = twitter_yesterday_active_users.to_set - twitter_daily_active_users.to_set
		twitter_one_week_inactive_users = twitter_last_week_active_users.to_set - twitter_weekly_active_users.to_set
		twitter_one_month_inactive_users = twitter_last_month_active_users.to_set - twitter_monthly_active_users.to_set
		twitter_daily_churn = twitter_daily_active_users.count == 0 ? 0 : twitter_one_day_inactive_users.count*1000/twitter_daily_active_users.count
		twitter_weekly_churn = twitter_weekly_active_users.count == 0 ? 0 : twitter_one_week_inactive_users.count*1000/twitter_weekly_active_users.count
		twitter_monthly_churn = twitter_monthly_active_users.count == 0 ? 0 : twitter_one_month_inactive_users.count*1000/twitter_monthly_active_users.count

		internal_daily_active_users = Post.internal_answers.where(:date => y.to_s).collect(&:user_id)
		internal_weekly_active_users = Post.internal_answers.where(:date => this_week_ary_of_days).collect(&:user_id)
		internal_monthly_active_users = Post.internal_answers.where(:date => this_month_ary_of_days).collect(&:user_id)
		internal_yesterday_active_users = Post.internal_answers.where(:date => (y-1).to_s).collect(&:user_id)
		internal_last_week_active_users = Post.internal_answers.where(:date => last_week_ary_of_days).collect(&:user_id)
		internal_last_month_active_users = Post.internal_answers.where(:date => last_month_ary_of_days).collect(&:user_id)
		internal_one_day_inactive_users = internal_yesterday_active_users.to_set - internal_daily_active_users.to_set
		internal_one_week_inactive_users = internal_last_week_active_users.to_set - internal_weekly_active_users.to_set
		internal_one_month_inactive_users = internal_last_month_active_users.to_set - internal_monthly_active_users.to_set
		internal_daily_churn = internal_daily_active_users.count == 0 ? 0 : internal_one_day_inactive_users.count*1000/internal_daily_active_users.count
		internal_weekly_churn = internal_weekly_active_users.count == 0 ? 0 : internal_one_week_inactive_users.count*1000/internal_weekly_active_users.count
		internal_monthly_churn = internal_monthly_active_users.count == 0 ? 0 : internal_one_month_inactive_users.count*1000/internal_monthly_active_users.count

		Stat.create(:asker_id => current_acct.id,
			:date => y.to_s,
	    :followers => followers,
	    :friends => friends,
	    :rts => rts,
	    :mentions => mentions,
	    :twitter_posts =>twitter_posts,
	    :tumblr_posts => tumblr_posts,
	    :facebook_posts => facebook_posts,
	    :internal_posts => internal_posts,
	    :twitter_answers => twitter_answers,
	    :tumblr_answers => tumblr_answers,
	    :facebook_answers => facebook_answers,
	    :internal_answers => internal_answers,
	    :twitter_daily_active_users => twitter_daily_active_users.to_set.count,
	    :twitter_weekly_active_users => twitter_weekly_active_users.to_set.count,
	    :twitter_monthly_active_users => twitter_monthly_active_users.to_set.count,
	    :twitter_one_day_inactive_users => twitter_one_day_inactive_users.to_set.count,
	    :twitter_one_week_inactive_users => twitter_one_week_inactive_users.to_set.count,
	    :twitter_one_month_inactive_users => twitter_one_month_inactive_users.to_set.count,
	    :twitter_daily_churn => twitter_daily_churn,
	    :twitter_weekly_churn => twitter_weekly_churn,
	    :twitter_monthly_churn => twitter_monthly_churn,
	    :internal_daily_active_users => internal_daily_active_users.to_set.count,
	    :internal_weekly_active_users => internal_weekly_active_users.to_set.count,
	    :internal_monthly_active_users => internal_monthly_active_users.to_set.count,
	    :internal_one_day_inactive_users => internal_one_day_inactive_users.to_set.count,
	    :internal_one_week_inactive_users => internal_one_week_inactive_users.to_set.count,
	    :internal_one_month_inactive_users => internal_one_month_inactive_users.to_set.count,
	    :internal_daily_churn => internal_daily_churn,
	    :internal_weekly_churn => internal_weekly_churn,
	    :internal_monthly_churn => internal_monthly_churn)
	end

	def self.get_yesterday(id)
		###get yesterdays stats or create dummy yesterday for math
		d = Date.today
		num_days_back = 2
		yesterday = Stat.find_by_date_and_asker_id((d - num_days_back.days).to_s, id)
		while yesterday.nil? and num_days_back <= 8
			num_days_back += 1
			yesterday = Stat.find_by_date_and_asker_id((d - num_days_back.days).to_s, id)
		end
		if yesterday.nil?
			yesterday = Stat.new
			asker_id = 0
			date = nil
	    followers = 0
	    friends = 0
	    rts = 0 
	    mentions = 0
	    twitter_posts = 0
	    tumblr_posts = 0
	    facebook_posts = 0
	    internal_posts = 0
	    twitter_answers = 0
	    tumblr_answers = 0
	    facebook_answers = 0
	    internal_answers = 0
	    twitter_daily_active_users = 0
	    twitter_weekly_active_users = 0
	    twitter_monthly_active_users = 0
	    twitter_one_day_inactive_users = 0
	    twitter_one_week_inactive_users = 0
	    twitter_one_month_inactive_users = 0
	    twitter_daily_churn = 0
			twitter_weekly_churn = 0
	    twitter_monthly_churn = 0
	    internal_daily_active_users = 0
	    internal_weekly_active_users = 0
	    internal_monthly_active_users = 0
	    internal_one_day_inactive_users = 0
	    internal_one_week_inactive_users = 0
	    internal_one_month_inactive_users = 0
	    internal_daily_churn = 0
	    internal_weekly_churn = 0
	    internal_monthly_churn = 0
	  end
		yesterday
	end

	def self.get_all_retweets(days)
		rts = Stat.where('updated_at > ? and updated_at < ?', Date.today - days, Date.today)
		rts_json = {}
		rts.each do |rt|
			rts_json[rt.date]=0 if rts_json[rt.date].nil?
			rts_json[rt.date]+= rt.rts.nil? ? 0 : rt.rts
		end
		rts_json
	end

	def self.get_all_dau(days)
		dau = Stat.where('updated_at > ? and updated_at < ?', Date.today - days, Date.today)
		puts dau
		dau_json = {}
		dau.each do |d|
			tdau = d.twitter_daily_active_users.nil? ? 0 : d.twitter_daily_active_users
			idau = d.internal_daily_active_users.nil? ? 0 : d.internal_daily_active_users  
			dau_json[d.date]=[0,0,0] if dau_json[d.date].nil?
			dau_json[d.date][0]+= tdau
			dau_json[d.date][1]+= idau 
			dau_json[d.date][2]+= tdau + idau
		end
		puts dau_json
		dau_json
	end

	def self.get_all_questions_answered(days)
		questions = Stat.where('updated_at > ? and updated_at < ?', Date.today - days, Date.today)
		q_json = {}
		questions.each do |q|
			ta = q.twitter_answers.nil? ? 0 : q.twitter_answers
			ia = q.internal_answers.nil? ? 0 : q.internal_answers

			q_json[q.date]=[0,0,0] if q_json[q.date].nil?
			q_json[q.date][0]+= ta
			q_json[q.date][1]+= ia
			q_json[q.date][2]+= ta + ia
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
			followers += w.followers.nil? ? 0 : w.followers
			tweets += w.twitter_posts.nil? ? 0 : w.twitter_posts
			questions_answered += w.twitter_answers.nil? ? 0 : w.twitter_answers
			questions_answered += w.internal_answers.nil? ? 0 : w.internal_answers
			dau += w.internal_daily_active_users.nil? ? 0 : w.internal_daily_active_users
			rts += w.rts.nil? ? 0 : w.rts
		end
		headsup= {'followers' => followers,
							'tweets' => tweets,
							'questions_answered' => questions_answered,
							'average_daily_active_users' => (dau/7.0).round(2),
							'weekly_active_users' => weekly_stats.last.internal_weekly_active_users,
							'rts' => rts,
							'weekly_churn' => weekly_stats.last.internal_weekly_churn}
	end

	def self.increment_cached_value(asker, attribute, value, user_id = nil)
		puts "increment cached values:"
		puts asker, attribute, value, user_id
	end
end
