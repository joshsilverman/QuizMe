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
		
		month_stats = Stat.where("asker_id in (?) and date > ?", asker_ids, 31.days.ago)
		date_grouped_stats = month_stats.group_by(&:date)

		month_posts = Post.not_spam.where("created_at > ? and user_id not in (?)", 1.month.ago, (asker_ids += ADMINS))
		date_grouped_posts = month_posts.group_by { |post| post.created_at.to_date }
		((Date.today - 31)..(Date.today - 1)).each do |date|
			graph_data[:total_followers][date], graph_data[:total_followers][date], graph_data[:click_throughs][date], graph_data[:active_user_ids][date], graph_data[:questions_answered][date], graph_data[:retweets][date], graph_data[:mentions][date] = {}, {}, {}, {}, {}, {}, {}
			if date_grouped_posts[date]
				date_grouped_posts[date].group_by { |post| post.in_reply_to_user_id }.each do |asker_id, asker_posts|
					graph_data[:retweets][date][asker_id] = asker_posts.select{ |p| p.interaction_type == 3 }.size
					graph_data[:mentions][date][asker_id] = asker_posts.select{ |p| p.interaction_type == 2 and p.correct.nil? }.size
					graph_data[:questions_answered][date][asker_id] = asker_posts.select{ |p| !p.correct.nil? }.size
					graph_data[:active_user_ids][date][asker_id] = asker_posts.select{ |p| !p.correct.nil? or [2, 3, 4].include? p.interaction_type }.collect(&:user_id)#.join(",")
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
	end

	def self.get_display_data(askers, today_active_user_ids = [], total_active_user_ids = [], display_data = {})
		asker_ids = askers.collect(&:id)
	
		todays_asker_grouped_posts = Post.not_spam.where("created_at > ? and user_id not in (?)", Time.zone.now.beginning_of_day, (asker_ids += ADMINS)).group_by(&:in_reply_to_user_id)
		months_asker_grouped_posts = Post.not_spam.select([:correct, :interaction_type, :user_id, :in_reply_to_user_id]).where("created_at > ? and user_id not in (?)", 1.month.ago, (asker_ids += ADMINS)).group_by(&:in_reply_to_user_id)

		months_asker_grouped_stats = Stat.select([:active_user_ids, :asker_id, :click_throughs, :total_followers]).where("asker_id in (?) and date > ?", asker_ids, 1.month.ago).group_by(&:asker_id)	

		totals = {:followers => {:total => 0, :today => 0}, :click_throughs => {:total => 0, :today => 0}, :active_users => {:total => [], :today => []}, :questions_answered => {:total => [], :today => 0}, :retweets => {:total => 0, :today => 0}, :mentions => {:total => 0, :today => 0}}
		asker_ids.each do |asker_id|
			display_data[asker_id] = {:followers => {:today => 0, :total => 0}, :click_throughs => {:today => 0, :total => 0}, :active_users => {:today => [], :total => []}, :questions_answered => {:today => 0, :total => []}, :retweets => {:today => 0, :total => 0}, :mentions => {:today => 0, :total => 0}}
			if todays_asker_grouped_posts[asker_id]
				display_data[asker_id][:mentions][:today] = todays_asker_grouped_posts[asker_id].select{ |p| p.interaction_type == 2 and p.correct.nil? }.size
				display_data[asker_id][:mentions][:total] = Post.not_spam.where("in_reply_to_user_id = ? and interaction_type = 2 and correct is null", asker_id).size
				totals[:mentions][:today] += display_data[asker_id][:mentions][:today]
				totals[:mentions][:total] += display_data[asker_id][:mentions][:total]

				display_data[asker_id][:retweets][:today] = todays_asker_grouped_posts[asker_id].select{ |p| p.interaction_type == 3 }.size
				display_data[asker_id][:retweets][:total] = Post.where(:in_reply_to_user_id => asker_id, :interaction_type => 3).size
				totals[:retweets][:today] += display_data[asker_id][:retweets][:today]
				totals[:retweets][:total] += display_data[asker_id][:retweets][:total]

				display_data[asker_id][:questions_answered][:today] = todays_asker_grouped_posts[asker_id].select{ |p| !p.correct.nil? }.size
				display_data[asker_id][:questions_answered][:total] = todays_asker_grouped_posts[asker_id].select{ |p| !p.correct.nil? }.collect(&:user_id).uniq
				# display_data[asker_id][:questions_answered][:total] = Post.where("in_reply_to_user_id = ? and correct is not null", asker_id).size
				totals[:questions_answered][:today] += display_data[asker_id][:questions_answered][:today]
				totals[:questions_answered][:total] += display_data[asker_id][:questions_answered][:total]		

				# DMs need to be marked as correct as well!
				display_data[asker_id][:active_users][:today] = todays_asker_grouped_posts[asker_id].select{ |p| !p.correct.nil? or [2, 3, 4].include? p.interaction_type }.collect(&:user_id).uniq
				totals[:active_users][:today] += display_data[asker_id][:active_users][:today]
			end

			if months_asker_grouped_posts[asker_id]
				display_data[asker_id][:active_users][:total] = months_asker_grouped_posts[asker_id].select{ |p| !p.correct.nil? or [2, 3, 4].include? p.interaction_type }.collect(&:user_id).uniq
				totals[:active_users][:total] += display_data[asker_id][:active_users][:total]
			end

			if months_asker_grouped_stats[asker_id]
				months_asker_grouped_stats[asker_id] ? last_stat = months_asker_grouped_stats[asker_id][-1] : last_stat = nil

				display_data[asker_id][:click_throughs][:total] = 0#Stat.where(:asker_id => asker_id).sum(:click_throughs)
				display_data[asker_id][:click_throughs][:today] = 0#last_stat ? last_stat.click_throughs : 0
				totals[:click_throughs][:total] += display_data[asker_id][:click_throughs][:total]
				totals[:click_throughs][:today] += display_data[asker_id][:click_throughs][:today]			

				display_data[asker_id][:followers][:total] = last_stat ? last_stat.total_followers : 0

				totals[:followers][:total] += display_data[asker_id][:followers][:total]
				if months_asker_grouped_stats[asker_id][-2]
					display_data[asker_id][:followers][:today] = months_asker_grouped_stats[asker_id][-1].total_followers - months_asker_grouped_stats[asker_id][-2].total_followers
				else
					display_data[asker_id][:followers][:today] = months_asker_grouped_stats[asker_id][-1].total_followers
				end
				totals[:followers][:today] += display_data[asker_id][:followers][:today]			
			end
		end
		totals[:active_users][:today].uniq!
		totals[:active_users][:total].uniq!
		totals[:questions_answered][:total].uniq!
		display_data[0] = totals
		return display_data
	end

	def self.paulgraham
		asker_ids = User.askers.collect(&:id)
		new_on = User.joins(:posts).where("((posts.interaction_type = 3 or posts.posted_via_app = ?) or ((posts.autospam = ? and posts.spam is null) or posts.spam = ?)) and users.id not in (?)", true, false, false, asker_ids).group("to_char(users.created_at, 'YYYY-MM-DD')").count('users.id', :distinct => true) #.group("date_part('week', users.created_at)").count
		existing_before = {}
		new_to_existing_before_on = {}
		domain = 30
		start_day = Date.today - (domain + 1).days

		existing_before[start_day - 1] = new_on\
			.reject{|w,c| Date.strptime(w, "%Y-%m-%d") > start_day - 1}
			.collect{|k,v| v}
			.sum

		((start_day)..(Date.today - 1)).to_a.each do |n|
			existing_before[n] = existing_before[n - 1] + new_on[(n - 1).to_s].to_i
			new_on[n.to_s] ||= 0
			new_to_existing_before_on[n] = {:raw => nil, :avg => nil}
			new_to_existing_before_on[n][:raw] = ((new_on[n.to_s].to_f / existing_before[n]) + 1) ** 7 - 1
			new_to_existing_before_on[n][:raw] = 0 if new_to_existing_before_on[n][:raw].nan? or new_to_existing_before_on[n][:raw].infinite?
		end
		existing_before[Date.today] = existing_before[Date.today - 1] + new_on[(Date.today - 1).to_s].to_i

		new_to_existing_before_on.map do |date, v|
			group = [v[:raw]]
			new_to_existing_before_on.map{|ddate,vv| group.push vv[:raw] if ddate < date and ddate > date - 7.days}
			new_to_existing_before_on[date][:avg] = group.sum/group.length
		end

		last_24_hours_new = User.joins(:posts).where("((posts.interaction_type = 3 or posts.posted_via_app = ?) or ((posts.autospam = ? and posts.spam is null) or posts.spam = ?)) and users.id not in (?)", true, false, false, asker_ids).where("users.created_at > ?", 24.hours.ago).count('users.id', :distinct => true)
		last_7_days_new = User.joins(:posts).where("((posts.interaction_type = 3 or posts.posted_via_app = ?) or ((posts.autospam = ? and posts.spam is null) or posts.spam = ?)) and users.id not in (?)", true, false, false, asker_ids).where("users.created_at > ?", (7 * 24).hours.ago).count('users.id', :distinct => true)

		display_data = {
			:today => (last_24_hours_new.to_f / existing_before[Date.today] + 1) ** 7 - 1,
			:total => last_7_days_new.to_f / existing_before[Date.today]
		}

		_new_to_existing_before_on = {}
		new_to_existing_before_on.map{|day,dat| _new_to_existing_before_on[day.strftime('%m/%d')] = dat}

		return _new_to_existing_before_on, display_data
	end

	def self.dau_mau
		asker_ids = User.askers.collect(&:id)
		date_grouped_posts = Post.not_spam\
				.where("created_at > ? and user_id not in (?)", 61.days.ago, (asker_ids += ADMINS))\
				.order("created_at ASC")\
				.group_by { |post| post.created_at.to_date }
		date_grouped_posts.each do |date, posts|
			date_grouped_posts[date] = posts.select{ |p| !p.correct.nil? or [2, 3, 4].include? p.interaction_type }.collect(&:user_id).uniq
		end

		graph_data = {}
		most_recent_mau = nil
		((Date.today - 31)..(Date.today - 1)).each do |date|
			total = []
			((date - 30)..date).each do |day|
				total += date_grouped_posts[day] unless date_grouped_posts[day].blank?
			end

			total = total.uniq.count
			graph_data[date] = date_grouped_posts[date].count.to_f / total unless total == 0
			most_recent_mau = total
		end

		last_24_hours_aus = Post.not_spam\
				.where("created_at > ? and user_id not in (?)", 24.hours.ago, (asker_ids += ADMINS))\
				.order("created_at ASC")\
				.group_by { |post| post.user_id }.keys.count

		display_data = {}
		display_data[:today] = last_24_hours_aus.to_f / most_recent_mau #0.99 #graph_data[Date.today]

		last_7_days = graph_data.reject{|k,v| 8.days.ago > k}.values
		display_data[:total] = last_7_days.sum / last_7_days.size
		return graph_data, display_data
	end

	def self.daus
		asker_ids = User.askers.collect(&:id)
		user_ids_by_date = Post.not_spam\
				.where("created_at > ? and created_at < ? and user_id not in (?)", 31.days.ago, Date.today, (asker_ids += ADMINS))\
				.order("created_at ASC")\
				.group_by { |post| post.created_at.to_date }

		graph_data = {}
		user_ids_by_date.each do |date, posts|
			graph_data[date] = posts.select{ |p| !p.correct.nil? or [2, 3, 4].include? p.interaction_type }.collect(&:user_id).uniq.count
		end

		display_data = {}
		display_data[:today] = Post.not_spam\
				.where("created_at > ? and user_id not in (?)", 24.hours.ago, (asker_ids += ADMINS))\
				.order("created_at ASC")\
				.group_by { |post| post.user_id }.keys.count
		display_data[:total] = Post.not_spam\
				.where("created_at > ? and user_id not in (?)", (24*30).hours.ago, (asker_ids += ADMINS))\
				.collect(&:user_id).uniq.count

		return graph_data, display_data
	end

	def self.econ_engine
    @posts_by_date = Post.joins(:user)\
        .where("in_reply_to_user_id IN (#{User.askers.collect(&:id).join(",")}) AND users.role != 'asker' AND user_id NOT IN (1,3,4,5,11,12,13,17,25,65,106)")\
        .where("posts.created_at > ?", Date.today - 30)\
        .where("((interaction_type = 3 or posted_via_app = ? or correct is not null) or ((autospam = ? and spam is null) or spam = ?))", true, false, false)\
        .where("interaction_type <> 4")\
        .select(["posts.created_at", :in_reply_to_user_id, :interaction_type, :spam, :autospam, "users.role", :user_id])\
        .order("posts.created_at DESC")\
        .group_by{|p| p.created_at.strftime('%m/%d')}

    @posts_by_date_by_asker = {}
    @posts_by_date.each{|date, posts| @posts_by_date_by_asker[date] = posts.group_by{|p| p.in_reply_to_user_id}}
    @econ_engine = @posts_by_date_by_asker
    @econ_engine.each{|date, posts_by_asker| posts_by_asker.each{|asker_id, posts| @econ_engine[date][asker_id] = posts.count}}

    @asker_ids = User.askers.collect(&:id)
    @asker_ids = Hash[@asker_ids.zip([0]*@asker_ids.count)]
    @econ_engine.each{|date, posts_by_asker| @econ_engine[date] = @asker_ids.merge(posts_by_asker).map{|k, v| [k, v]}.sort{|x,y| x[0] <=> y[0]}.map{|r| r[1]}}
		@econ_engine = @econ_engine.map{|k, v| [k, v].flatten}
		@econ_engine = @econ_engine.sort{|x,y| x[0] <=> y[0]}
		@econ_engine = [['Date'] + User.askers.sort{|x,y| x.id <=> y.id}.collect(&:twi_screen_name)] + @econ_engine

		display_data = {}
		display_data[:today] = @econ_engine.last[1..100].sum
		display_data[:answerers] = @posts_by_date.map{|k, v| [k, v]}.sort{|x,y| x[0] <=> y[0]}.last[1].group_by{|p| p.user_id}.count

		return @econ_engine, display_data
	end

end