class Stat < ActiveRecord::Base
	belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'

	def self.update_stats_from_cache(asker)
		today = Date.today.to_date
		stat = Stat.where(:date => today, :asker_id => asker.id).first
		if stat.blank?
			stat = Stat.new
			stat.asker_id = asker.id
			stat.date = today
		end		
		total_followers = asker.twitter.user.followers_count
		stat.total_followers = total_followers
		if previous_stat = Stat.where("date < ? and asker_id = ?", today, asker.id).order("date DESC").limit(1).first
			stat.followers = total_followers - previous_stat.total_followers
		else
			stat.followers = 0
		end		
		stat.save
		stats_hash = Rails.cache.read("stats:#{asker.id}")
		unless stats_hash.blank?
			Hash[stats_hash.sort].each do |date, attributes_hash|
				stat = Stat.where(:date => date, :asker_id => asker.id).order("date DESC").limit(1).first
				stat = Stat.new if stat.blank?
				stat.date = date
				stat.asker_id = asker.id
				attributes_hash.each do |attribute, value|
					if attribute == "active_users"
						if stat.active_user_ids.blank?
							stat.active_user_ids += value
						else
							stat.active_user_ids += ",#{value}"
						end
						stat.active_users = stat.active_user_ids.split(",").uniq.size
					else
						stat.increment attribute, value
					end
				end			
				stat.save
			end		
		end
	end

	def self.update_stat_cache(attribute, value, asker_id, date, user_id)
		return if ADMINS.include? user_id
		date = date.to_date
		stats_hash = Rails.cache.read("stats:#{asker_id}") || {}
		stats_hash = stats_hash.dup
		stats_hash[date] = {} unless stats_hash.has_key? date
		if attribute == "active_users"
			stats_hash[date][attribute] = "" unless stats_hash[date][attribute]
			if stats_hash[date][attribute].present?
				stats_hash[date][attribute] += ",#{value}"
			else
				stats_hash[date][attribute] += "#{value}"
			end
		else
			stats_hash[date][attribute] = 0 unless stats_hash[date][attribute]
			stats_hash[date][attribute] += value
		end
		Rails.cache.write("stats:#{asker_id}", stats_hash)
	end

	def self.get_month_graph_data(askers)
		asker_ids = askers.collect(&:id)
		graph_data = {:total_followers => {}, :click_throughs => {}, :active_user_ids => {}, :questions_answered => {}, :retweets => {}, :mentions => {}}
		
		month_stats = Stat.where("asker_id in (?) and date > ?", asker_ids, 1.month.ago)
		date_grouped_stats = month_stats.group_by(&:date)

		month_posts = Post.where("created_at > ? and user_id not in (?) and (spam = ? or spam is null)", 1.month.ago, (asker_ids += ADMINS), false)

		date_grouped_posts = month_posts.group_by { |post| post.created_at.to_date }
		((Date.today - 30)..Date.today).each do |date|
			graph_data[:total_followers][date], graph_data[:total_followers][date], graph_data[:click_throughs][date], graph_data[:active_user_ids][date], graph_data[:questions_answered][date], graph_data[:retweets][date], graph_data[:mentions][date] = {}, {}, {}, {}, {}, {}, {}
			if date_grouped_posts[date]
				date_grouped_posts[date].group_by { |post| post.in_reply_to_user_id }.each do |asker_id, asker_posts|
					graph_data[:retweets][date][asker_id] = asker_posts.select{ |p| p.interaction_type == 3 }.size
					graph_data[:mentions][date][asker_id] = asker_posts.select{ |p| p.interaction_type == 2 and p.correct.nil? }.size
					graph_data[:questions_answered][date][asker_id] = asker_posts.select{ |p| !p.correct.nil? }.size
					graph_data[:active_user_ids][date][asker_id] = asker_posts.select{ |p| !p.correct.nil? or [2,3].include? p.interaction_type }.collect(&:user_id)#.join(",")
					# graph_data[:dms][date][asker_id] = asker_posts.select{ |p| p.interaction_type == 4 }.size
				end
			end
			if date_grouped_stats[date]
				date_grouped_stats[date].each do |stat|
					graph_data[:click_throughs][date][stat.asker_id] = 0#stat.click_throughs
					graph_data[:total_followers][date][stat.asker_id] = stat.total_followers
				end
			end
		end
		return graph_data
		# asker_ids = askers.collect(&:id)
		# month_stats = Stat.where("asker_id in (?) and date > ?", asker_ids, 1.month.ago)
		# date_grouped_stats = month_stats.group_by(&:date)
		# graph_data = {:total_followers => {}, :click_throughs => {}, :active_user_ids => {}, :questions_answered => {}, :retweets => {}, :mentions => {}}
		# ((Date.today - 30)..Date.today).each do |date|
		# 	graph_data.each do |key, value|
		# 		graph_data[key][date] = {}
		# 		next unless date_grouped_stats[date]
		# 		date_grouped_stats[date].each do |stat|
		# 			graph_data[key][date][stat.asker_id] = (key == :active_user_ids ? stat[key].split(",").uniq : stat[key])
		# 		end
		# 	end  
		# end
	end

	def self.get_display_data(askers, today_active_user_ids = [], total_active_user_ids = [], display_data = {})
		asker_ids = askers.collect(&:id)

		todays_asker_grouped_posts = Post.where("created_at > ? and user_id not in (?) and (spam = ? or spam is null)", Time.zone.now.beginning_of_day, (asker_ids += ADMINS), false).group_by(&:in_reply_to_user_id)
		
		months_asker_grouped_stats = Stat.select([:active_user_ids, :asker_id, :click_throughs, :total_followers]).where("asker_id in (?) and date > ?", asker_ids, 1.month.ago).group_by(&:asker_id)
		months_asker_grouped_posts = Post.select([:correct, :interaction_type, :user_id, :in_reply_to_user_id]).where("created_at > ? and user_id not in (?) and (spam = ? or spam is null)", 1.month.ago, (asker_ids += ADMINS), false).group_by(&:in_reply_to_user_id)

		totals = {:followers => {:total => 0, :today => 0}, :click_throughs => {:total => 0, :today => 0}, :active_users => {:total => [], :today => []}, :questions_answered => {:total => 0, :today => 0}, :retweets => {:total => 0, :today => 0}, :mentions => {:total => 0, :today => 0}}
		asker_ids.each do |asker_id|
			next if todays_asker_grouped_posts[asker_id].nil?
			display_data[asker_id] = {:followers => {}, :click_throughs => {}, :active_users => {}, :questions_answered => {}, :retweets => {}, :mentions => {}}

			display_data[asker_id][:mentions][:today] = todays_asker_grouped_posts[asker_id].select{ |p| p.interaction_type == 2 and p.correct.nil? }.size
			display_data[asker_id][:mentions][:total] = Post.where("in_reply_to_user_id = ? and interaction_type = 2 and correct is null and (spam = ? or spam is null)", asker_id, false).size
			totals[:mentions][:today] += display_data[asker_id][:mentions][:today]
			totals[:mentions][:total] += display_data[asker_id][:mentions][:total]

			display_data[asker_id][:retweets][:today] = todays_asker_grouped_posts[asker_id].select{ |p| p.interaction_type == 3 }.size
			display_data[asker_id][:retweets][:total] = Post.where(:in_reply_to_user_id => asker_id, :interaction_type => 3).size
			totals[:retweets][:today] += display_data[asker_id][:retweets][:today]
			totals[:retweets][:total] += display_data[asker_id][:retweets][:total]

			display_data[asker_id][:questions_answered][:today] = todays_asker_grouped_posts[asker_id].select{ |p| !p.correct.nil? }.size
			display_data[asker_id][:questions_answered][:total] = Post.where("in_reply_to_user_id = ? and correct is not null", asker_id).size
			totals[:questions_answered][:today] += display_data[asker_id][:questions_answered][:today]
			totals[:questions_answered][:total] += display_data[asker_id][:questions_answered][:total]			

			# DMs need to be marked as correct as well!
			display_data[asker_id][:active_users][:today] = todays_asker_grouped_posts[asker_id].select{ |p| !p.correct.nil? or [2,3].include? p.interaction_type }.collect(&:user_id).uniq
			display_data[asker_id][:active_users][:total] = months_asker_grouped_posts[asker_id].select{ |p| !p.correct.nil? or [2,3].include? p.interaction_type }.collect(&:user_id).uniq
			totals[:active_users][:today] += display_data[asker_id][:active_users][:today]
			totals[:active_users][:total] += display_data[asker_id][:active_users][:total]

			display_data[asker_id][:click_throughs][:total] = Stat.where(:asker_id => asker_id).sum(:click_throughs)
			display_data[asker_id][:click_throughs][:today] = months_asker_grouped_stats[asker_id][-1].click_throughs
			# display_data[0][:click_throughs][:total] += display_data[asker_id][:click_throughs][:total]
			# display_data[0][:click_throughs][:today] += display_data[asker_id][:click_throughs][:today]			

			display_data[asker_id][:followers][:total] = months_asker_grouped_stats[asker_id][-1].total_followers
			totals[:followers][:total] += display_data[asker_id][:followers][:total]
			if months_asker_grouped_stats[asker_id][-2]
				display_data[asker_id][:followers][:today] = months_asker_grouped_stats[asker_id][-1].total_followers - months_asker_grouped_stats[asker_id][-2].total_followers
			else
				display_data[asker_id][:followers][:today] = months_asker_grouped_stats[asker_id][-1].total_followers
			end
			totals[:followers][:today] += display_data[asker_id][:followers][:today]			
		end
		totals[:active_users][:today].uniq!
		totals[:active_users][:total].uniq!
		display_data[0] = totals
		return display_data
	end

	# def self.get_yesterday(id)
	# 	###get yesterdays stats or create dummy yesterday for math
	# 	d = Date.today
	# 	num_days_back = 2
	# 	yesterday = Stat.find_by_date_and_asker_id((d - num_days_back.days).to_s, id)
	# 	while yesterday.nil? and num_days_back <= 8
	# 		num_days_back += 1
	# 		yesterday = Stat.find_by_date_and_asker_id((d - num_days_back.days).to_s, id)
	# 	end
	# 	if yesterday.nil?
	# 		yesterday = Stat.new
	# 		asker_id = 0
	# 		date = nil
	#     followers = 0
	#     friends = 0
	#     rts = 0 
	#     mentions = 0
	#     twitter_posts = 0
	#     tumblr_posts = 0
	#     facebook_posts = 0
	#     internal_posts = 0
	#     twitter_answers = 0
	#     tumblr_answers = 0
	#     facebook_answers = 0
	#     internal_answers = 0
	#     twitter_daily_active_users = 0
	#     twitter_weekly_active_users = 0
	#     twitter_monthly_active_users = 0
	#     twitter_one_day_inactive_users = 0
	#     twitter_one_week_inactive_users = 0
	#     twitter_one_month_inactive_users = 0
	#     twitter_daily_churn = 0
	# 		twitter_weekly_churn = 0
	#     twitter_monthly_churn = 0
	#     internal_daily_active_users = 0
	#     internal_weekly_active_users = 0
	#     internal_monthly_active_users = 0
	#     internal_one_day_inactive_users = 0
	#     internal_one_week_inactive_users = 0
	#     internal_one_month_inactive_users = 0
	#     internal_daily_churn = 0
	#     internal_weekly_churn = 0
	#     internal_monthly_churn = 0
	#   end
	# 	yesterday
	# end

	# def self.get_all_retweets(days)
	# 	rts = Stat.where('updated_at > ? and updated_at < ?', Date.today - days, Date.today)
	# 	rts_json = {}
	# 	rts.each do |rt|
	# 		rts_json[rt.date]=0 if rts_json[rt.date].nil?
	# 		rts_json[rt.date]+= rt.rts.nil? ? 0 : rt.rts
	# 	end
	# 	rts_json
	# end

	# def self.get_all_dau(days)
	# 	dau = Stat.where('updated_at > ? and updated_at < ?', Date.today - days, Date.today)
	# 	puts dau
	# 	dau_json = {}
	# 	dau.each do |d|
	# 		tdau = d.twitter_daily_active_users.nil? ? 0 : d.twitter_daily_active_users
	# 		idau = d.internal_daily_active_users.nil? ? 0 : d.internal_daily_active_users  
	# 		dau_json[d.date]=[0,0,0] if dau_json[d.date].nil?
	# 		dau_json[d.date][0]+= tdau
	# 		dau_json[d.date][1]+= idau 
	# 		dau_json[d.date][2]+= tdau + idau
	# 	end
	# 	puts dau_json
	# 	dau_json
	# end

	# def self.get_all_questions_answered(days)
	# 	questions = Stat.where('updated_at > ? and updated_at < ?', Date.today - days, Date.today)
	# 	q_json = {}
	# 	questions.each do |q|
	# 		ta = q.twitter_answers.nil? ? 0 : q.twitter_answers
	# 		ia = q.internal_answers.nil? ? 0 : q.internal_answers

	# 		q_json[q.date]=[0,0,0] if q_json[q.date].nil?
	# 		q_json[q.date][0]+= ta
	# 		q_json[q.date][1]+= ia
	# 		q_json[q.date][2]+= ta + ia
	# 	end
	# 	q_json
	# end

	# def self.get_all_headsup
	# 	this_week = Stat.where('updated_at > ? and updated_at < ?', Date.today - 7, Date.today)
	# 	last_week = Stat.where('updated_at > ? and updated_at < ?', Date.today - 14, Date.today - 7)
	# 	tw = Stat.build_headsup_json(this_week)
	# 	lw = Stat.build_headsup_json(last_week)
	# 	headsup = {}
	# 	tw.each do |k,v|
	# 		headsup[k] = (v.nil? or lw[k].nil?) ? [nil, nil] : [v, (((v-lw[k])/lw[k].to_f)*100).round(2)]
	# 	end
	# 	headsup
	# end

	# def self.internal_retention(days, units)
	# 	config = {'api_key' => '413bec33f14dd73948f749abfbec3df4',
	# 		'api_secret' => '323f327138ee4227124f1480f8a1449e'}
	# 	client = Mixpanel::Client.new(config)
	# 	data = client.request do
	# 	  resource       'retention'
	# 		from_date      "#{Date.today - days}"
	# 		to_date        "#{Date.today}"
	# 		retention_type 'birth'
	# 		born_event     'PageLoaded'
	# 		born_where     '"review" in properties["url"]'
	# 		unit           "#{units}"
	# 		interval_count '10'
	# 	end
	# 	puts data
	# 	data
	# end

	# def self.twitter_retention(days)

	# end

	# def self.build_headsup_json(weekly_stats)
	# 	followers = 0
	# 	tweets = 0
	# 	questions_answered = 0
	# 	dau = 0
	# 	rts = 0
	# 	return {} if weekly_stats.nil? or weekly_stats.empty?
	# 	weekly_stats.each do |w|
	# 		followers += w.followers.nil? ? 0 : w.followers
	# 		tweets += w.twitter_posts.nil? ? 0 : w.twitter_posts
	# 		questions_answered += w.twitter_answers.nil? ? 0 : w.twitter_answers
	# 		questions_answered += w.internal_answers.nil? ? 0 : w.internal_answers
	# 		dau += w.internal_daily_active_users.nil? ? 0 : w.internal_daily_active_users
	# 		rts += w.rts.nil? ? 0 : w.rts
	# 	end
	# 	headsup= {'followers' => followers,
	# 						'tweets' => tweets,
	# 						'questions_answered' => questions_answered,
	# 						'average_daily_active_users' => (dau/7.0).round(2),
	# 						'weekly_active_users' => weekly_stats.last.internal_weekly_active_users,
	# 						'rts' => rts,
	# 						'weekly_churn' => weekly_stats.last.internal_weekly_churn}
	# end
end