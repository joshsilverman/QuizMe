class Stat < ActiveRecord::Base
  belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'

  def self.followers_count
    Rails.cache.fetch "stats_followers count", :expires_in => 1.hour do
      Stat.where("created_at > ? and created_at < ?", Date.yesterday.beginning_of_day, Date.yesterday.end_of_day).sum(:total_followers) || 0
    end
  end

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

  def self.paulgraham asker_id = nil, domain = 30

    asker_ids = User.askers.collect(&:id)
    
    if asker_id
      new_on = User.social_not_spam_with_posts\
        .where('posts.in_reply_to_user_id = ?', asker_id)\
        .group("to_char(users.created_at, 'YYYY-MM-DD')")\
        .count('users.id', :distinct => true)

      last_24_hours_new = User.social_not_spam_with_posts\
        .where('posts.in_reply_to_user_id = ?', asker_id)\
        .where("users.created_at > ?", 24.hours.ago).count('users.id', :distinct => true)
      last_7_days_new = User.social_not_spam_with_posts\
        .where('posts.in_reply_to_user_id = ?', asker_id)\
        .where("users.created_at > ?", (7 * 24).hours.ago).count('users.id', :distinct => true)
    else
      new_on = User.social_not_spam_with_posts\
        .group("to_char(users.created_at, 'YYYY-MM-DD')")\
        .count('users.id', :distinct => true)

      last_24_hours_new = User.social_not_spam_with_posts.where("users.created_at > ?", 24.hours.ago).count('users.id', :distinct => true)
      last_7_days_new = User.social_not_spam_with_posts.where("users.created_at > ?", (7 * 24).hours.ago).count('users.id', :distinct => true)
    end

    existing_before = {}
    new_to_existing_before_on = {}
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

    display_data = {
      :today => (last_24_hours_new.to_f / existing_before[Date.today] + 1) ** 7 - 1,
      :total => last_7_days_new.to_f / existing_before[Date.today]
    }

    display_data[:today] = sprintf "%.1f%", display_data[:today] * 100
    display_data[:total] = sprintf "%.1f%", display_data[:total] * 100

    _new_to_existing_before_on = {}
    new_to_existing_before_on.map{|day,dat| _new_to_existing_before_on[day.strftime('%m/%d')] = dat}

    return _new_to_existing_before_on, display_data
  end

  def self.dau_mau asker_id = nil
    domain = 30
    asker_ids = User.askers.collect(&:id)

    if asker_id
      user_ids_by_date_raw = Post.social.not_us.not_spam\
        .where('in_reply_to_user_id = ?', asker_id)\
        .where("created_at > ?", Date.today - (domain + 31).days)\
        .select(["to_char(posts.created_at, 'MM/DD')", "array_to_string(array_agg(user_id),',')"]).group("to_char(posts.created_at, 'MM/DD')").all    

      user_ids_last_24_raw = Post.social.not_us.not_spam\
        .where('in_reply_to_user_id = ?', asker_id)\
        .where("created_at > ?", 24.hour.ago)\
        .select(["to_char(posts.created_at, 'YY')", "array_to_string(array_agg(user_id),',')"]).group("to_char(posts.created_at, 'YY')").all
    else
      user_ids_by_date_raw = Post.social.not_us.not_spam\
        .where("created_at > ?", Date.today - (domain + 31).days)\
        .select(["to_char(posts.created_at, 'MM/DD')", "array_to_string(array_agg(user_id),',')"]).group("to_char(posts.created_at, 'MM/DD')").all

      user_ids_last_24_raw = Post.social.not_us.not_spam\
        .where("created_at > ?", 24.hour.ago)\
        .select(["to_char(posts.created_at, 'YY')", "array_to_string(array_agg(user_id),',')"]).group("to_char(posts.created_at, 'YY')").all
    end

    user_ids_by_date = {}
    user_ids_by_date_raw.each do |post|
      user_ids_by_date[post.to_char] = post.array_to_string.split(',').uniq
    end
    user_ids_last_24 = []
    user_ids_last_24 = user_ids_last_24_raw[0].array_to_string.split(',').uniq unless user_ids_last_24_raw.blank?

    graph_data = {}
    mau = []
    ((Date.today - (domain + 1))..(Date.today - 1)).each do |date|
      datef = date.strftime("%m/%d")
      graph_data[datef] = 0
      dau = 0
      dau = user_ids_by_date[datef].count if user_ids_by_date[datef]
      mau = []
      ((date - domain)..date).each do |ddate|
        ddatef = ddate.strftime("%m/%d")
        mau += user_ids_by_date[ddatef] unless user_ids_by_date[ddatef].blank?
      end
      mau = mau.uniq.count
      graph_data[datef] = dau.to_f / mau.to_f unless mau == 0
    end

    display_data = {}
    display_data[:today] = user_ids_last_24.count.to_f / mau #0.99 #graph_data[Date.today]

    last_7_days = graph_data.reject{|k,v| 8.days.ago > Date.strptime("#{Date.today.year}/#{k}", '%Y/%m/%d')}.values
    if last_7_days.size > 0
      display_data[:total] = last_7_days.sum / last_7_days.size
    else
      display_data[:total] = 0
    end

    display_data[:today] = sprintf "%.1f%", display_data[:today] * 100
    display_data[:total] = sprintf "%.1f%", display_data[:total] * 100

    return graph_data, display_data
  end

  def self.daus asker_id = nil, domain = 30
    asker_ids = User.askers.collect(&:id)

    display_data = {}
    if asker_id
      user_ids_by_date = Post.social.not_spam.not_us\
          .where('posts.in_reply_to_user_id = ?', asker_id)\
          .where("created_at > ? and created_at < ?", Date.today - (domain + 1).days, Date.today)\
          .order("created_at ASC")\
          .group_by { |post| post.created_at.to_date }
      display_data[:today] = Post.social.not_spam.not_us\
          .where('posts.in_reply_to_user_id = ?', asker_id)\
          .where("created_at > ?", 24.hours.ago)\
          .order("created_at ASC")\
          .group_by { |post| post.user_id }.keys.count
      display_data[:total] = Post.social.not_spam.not_us\
          .where('posts.in_reply_to_user_id = ?', asker_id)\
          .where("created_at > ?", (24*domain).hours.ago)\
          .collect(&:user_id).uniq.count
    else
      user_ids_by_date = Post.social.not_spam.not_us\
          .where("created_at > ? and created_at < ?", Date.today - (domain + 1).days, Date.today)\
          .order("created_at ASC")\
          .group_by { |post| post.created_at.to_date }
      display_data[:today] = Post.social.not_spam.not_us\
          .where("created_at > ?", 24.hours.ago)\
          .order("created_at ASC")\
          .group_by { |post| post.user_id }.keys.count
      display_data[:total] = Post.social.not_spam.not_us\
          .where("created_at > ?", (24*domain).hours.ago)\
          .collect(&:user_id).uniq.count
    end

    graph_data = {}
    user_ids_by_date.each do |date, posts|
      graph_data[date] = posts.select{ |p| !p.correct.nil? or [2, 3, 4].include? p.interaction_type }.collect(&:user_id).uniq.count
    end

    return graph_data, display_data
  end

  def self.econ_engine asker_id = nil, domain = 30
    
    if asker_id
      @posts_by_date = Post.joins(:user).not_us.not_spam.social\
          .where('posts.in_reply_to_user_id = ?', asker_id)\
          .where("posts.created_at > ?", Date.today - domain)\
          .select(["posts.created_at", :in_reply_to_user_id, :interaction_type, :spam, :autospam, "users.role", :user_id])\
          .group("to_char(posts.created_at, 'MM/DD')")\
          .count('posts.id')

    else
      @posts_by_date = Post.joins(:user).not_spam.not_us.social\
          .where("in_reply_to_user_id IN (#{Asker.all.collect(&:id).join(",")})")\
          .where("posts.created_at > ?", Date.today - domain)\
          .select(["posts.created_at", :in_reply_to_user_id, :interaction_type, :spam, :autospam, "users.role", :user_id])\
          .group("to_char(posts.created_at, 'MM/DD')")\
          .count('posts.id')
    end

    @econ_engine = []
    @posts_by_date.each{|date, post_count| @econ_engine << [date, post_count]}

    @econ_engine.sort!{|a,b| a[0] <=> b[0]}
    @econ_engine = [['Date', 'Soc. Actions']] + @econ_engine
    # puts @econ_engine

    display_data = {}
    display_data[:today] = @econ_engine.last[1]
    display_data[:month] = @econ_engine.collect{|r| r[1]}[1..-1].sum

    return @econ_engine, display_data
  end

  def self.revenue(client_id = nil, domain = 30)
    @client = Client.joins([:rate_sheet]).first #temporarily one client
    return unless @client
    @askers = @client.askers
    return unless @askers

    @posts_by_date = Post.not_spam.social.not_us\
        .where("in_reply_to_user_id IN (?)", @askers.collect(&:id))\
        .select([:text, "posts.created_at", :in_reply_to_user_id, :interaction_type, :correct, :user_id, :spam, :autospam])\
        .order("posts.created_at ASC")\
        .group_by{|p| p.created_at.strftime('%m/%d')}

    @revenue = [['Date', 'Revenue']]
    @posts_by_date.each do |date, posts|
      posts_by_interaction_type = posts.group_by{|p| p.interaction_type}

      rt_revenue = tweet_revenue = 0
      tweet_revenue = posts_by_interaction_type[2].count * @client.rate_sheet.tweet if posts_by_interaction_type[2]
      rt_revenue = posts_by_interaction_type[3].count * @client.rate_sheet.retweet if posts_by_interaction_type[3]

      next if date == Date.today.strftime('%m/%d')
      @revenue << [date, tweet_revenue + rt_revenue]
    end

    #heads up
    posts = {}
    posts[:today] = Post.not_spam.social.not_us.where("created_at > ?", 24.hours.ago).where("in_reply_to_user_id IN (?)", @askers.collect(&:id))
    posts[:month] = Post.not_spam.social.not_us.where("created_at > ?", 30.days.ago).where("in_reply_to_user_id IN (?)", @askers.collect(&:id))

    display_data = {:today => '', :month => ''}
    [:today, :month].each do |period|
      posts_by_interaction_type = posts[period].group_by{|p| p.interaction_type}

      rt_revenue = tweet_revenue = 0
      tweet_revenue = posts_by_interaction_type[2].count * @client.rate_sheet.tweet if posts_by_interaction_type[2]
      rt_revenue = posts_by_interaction_type[3].count * @client.rate_sheet.retweet if posts_by_interaction_type[3]
      display_data[period] = tweet_revenue + rt_revenue
    end

    display_data[:today] = sprintf "$%.2f", display_data[:today]
    display_data[:month] = sprintf "$%.2f", display_data[:month]

    return @revenue, display_data
  end

  def self.handle_activity(handle_activity = {}, graph_data = [])
    # y axis label
    # revert active
    title_row = ['Handle']
    User.askers.select([:id, :twi_screen_name]).all.each { |asker| handle_activity[asker.id] = [asker.twi_screen_name] }
    user_grouped_posts = Post.joins(:user).not_spam.not_us.social
      .where("posts.in_reply_to_user_id IN (?)", User.askers.collect(&:id))
      .where("posts.created_at > ?", 1.week.ago)
      .where("interaction_type <> 4")
      .select([:user_id, :in_reply_to_user_id])
      .order("posts.created_at DESC")
      .group_by(&:user_id)
    user_names = User.select([:id, :twi_screen_name]).find(user_grouped_posts.keys).group_by(&:id)
    user_grouped_posts.each do |user_id, users_posts|
      asker_grouped_user_posts = users_posts.group_by(&:in_reply_to_user_id)
      title_row << user_names[user_id][0].twi_screen_name
      handle_activity.each { |k, v| handle_activity[k] << (asker_grouped_user_posts[k].present? ? asker_grouped_user_posts[k].length : 0) }
    end
    handle_activity.each { |k, v| graph_data << v }
    graph_data.sort! { |a, b| b.drop(1).sum <=> a.drop(1).sum }
    graph_data.insert 0, title_row
    # puts graph_data.to_json
    return graph_data
  end

	def self.cohort_analysis(grouped_posts = {}, graph_data = [])
    title_row = ["Week"]
    start_day = 8.weeks.ago.to_date
    domain = 4.weeks.ago.to_date
    domain_posts = Post.joins(:user)\
      .not_spam\
      .not_us\
      .social\
      .select("to_char(users.created_at, 'MM/W') as week, posts.created_at, posts.user_id")
    weeks = domain_posts.order("users.created_at ASC").uniq_by(&:week).collect {|p| p.week}
    graph_data << (title_row += weeks)
    date_grouped_posts = domain_posts.order("posts.created_at ASC").group_by { |p| p.created_at.to_date.to_s }
    (domain..Date.today.to_date).each do |date|
      data = [date]
      date_posts = date_grouped_posts[date.to_s] || []
      week_grouped_posts = date_posts.group_by { |p| p.week }
      weeks.each do |week|
        data << (week_grouped_posts[week].present? ? week_grouped_posts[week].uniq{ |p| p.user_id }.size : 0)     
      end
      graph_data << data
    end
    return graph_data
	end

  def self.questions(domain = 60)
    # Median
    graph_data = [["Date", "Answered"]]
    day_grouped_answers = Post.social.not_us.not_spam\
      .where("created_at > ? and correct is not null", Date.today - domain.days)\
      .select(["to_char(created_at, 'MM/DD') as date", "array_to_string(array_agg(user_id),',') as user_ids"])\
      .group("to_char(created_at, 'MM/DD')").all.group_by { |a| a.date }
    ((domain.days.ago.to_date)..Date.today.to_date).each do |date|
      formatted_date = date.strftime("%m/%d")
      next if day_grouped_answers[formatted_date].blank?
      data = [formatted_date]
      counts = []
      values = day_grouped_answers[formatted_date][0].user_ids.split(",")
      values.each do |e|
        counts << values.count(e)
        values.delete(e)
      end
      data << counts.sort![(counts.length.to_f / 2).floor]
      graph_data << data
    end

    # Mean
    # day_grouped_answer_count = Post.social.not_us.not_spam\
    #   .where("created_at > ? and correct is not null", Date.today - domain.days)\
    #   .select(["to_char(created_at, 'MM/DD')"])\
    #   .group("to_char(created_at, 'MM/DD')")\
    #   .count
    # # "array_to_string(array_agg(user_id),',')"]).group("to_char(posts.created_at, 'YY')").all
    # day_grouped_user_count = Post.social.not_us.not_spam\
    #   .where("created_at > ? and correct is not null", Date.today - domain.days)\
    #   .select("to_char(created_at, 'MM/DD')")\
    #   .group("to_char(created_at, 'MM/DD')")\
    #   .count 'user_id', :distinct => true
    # ((domain.days.ago.to_date)..Date.today.to_date).each do |date|
    #   formatted_date = date.strftime("%m/%d")
    #   next if day_grouped_answer_count[formatted_date].blank? or day_grouped_user_count[formatted_date].blank?
    #   data = [formatted_date]
    #   data << day_grouped_answer_count[formatted_date].to_f / day_grouped_user_count[formatted_date].to_f
    #   graph_data << data
    # end
    return graph_data
  end

  def self.ugc(domain = 30)
    graph_data = [["Date", "# Created"]]
    day_grouped_questions = Question.where("created_at > ?", domain.days.ago)\
      .not_us\
      .group("to_char(created_at, 'MM-DD')")\
      .count
    ((domain.days.ago.to_date)..Date.today.to_date).each do |date|
      formatted_date = date.strftime("%m-%d")
      data = [formatted_date]
      data << (day_grouped_questions[formatted_date] || 0)
      graph_data << data
    end    
    return graph_data
  end

  def self.answer_source(domain = 8)
    graph_data = [["Date", "Wisr", "Twitter"]]
    off_site = Post.where("created_at > ? and correct is not null and posted_via_app = ?", domain.weeks.ago, false)\
      .group("to_char(created_at, 'MM-DD')")\
      .count
    on_site = Post.where("created_at > ? and correct is not null and posted_via_app = ?", domain.weeks.ago, true)\
      .group("to_char(created_at, 'MM-DD')")\
      .count
    ((domain.weeks.ago.to_date)..Date.today.to_date).each do |date|
      formatted_date = date.strftime("%m-%d")
      data = [formatted_date]
      data << (on_site[formatted_date] || 0)
      data << (off_site[formatted_date] || 0)
      graph_data << data
    end
    return graph_data
  end

  def self.learner_levels
    graph_data = [['learner level', 'users']]
    LEARNER_LEVELS.each do |level|
      next if level == "unengaged"
      graph_data << [level, User.count(:conditions => "learner_level = '#{level}'")]
    end
    return graph_data
  end
end