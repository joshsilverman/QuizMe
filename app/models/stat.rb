class Stat < ActiveRecord::Base
  belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'

  def self.followers_count
    Rails.cache.fetch "stats_followers count", :expires_in => 1.hour do
      Asker.all.collect {|a| a.followers.collect(&:id) }.flatten.uniq.size
    end
  end

  def self.paulgraham domain = 30
    new_to_existing_before_on, display_data = Rails.cache.fetch "stat_paulgraham_domain_#{domain}", :expires_in => 17.minutes do

      new_on = {}
      Post.not_spam.not_us.social\
        .select(["user_id", "to_char(min(created_at), 'YYYY-MM-DD') as first_active_at"])\
        .group("user_id").group_by{|p|p.first_active_at}.each{|k,v| new_on[k] = v.count}

      created_at_to_user_id = Hash[*Post.not_spam.not_us.social\
        .select(["user_id", "min(created_at) as first_active_at"])\
        .group("user_id").map{|p|[Time.parse(p.first_active_at), p.user_id]}.flatten]
      last_24_hours_new = created_at_to_user_id.keys.reject{|t|t < Time.now - 1.day}.count
      last_7_days_new = created_at_to_user_id.keys.reject{|t|t < Time.now - 7.days}.count

      existing_before = {}
      new_to_existing_before_on = {}
      start_day = Date.today - (domain + 1).days

      existing_before[start_day - 1] = new_on\
        .reject{|w,c| Date.strptime(w, "%Y-%m-%d") > start_day - 1}\
        .collect{|k,v| v}\
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

      [_new_to_existing_before_on, display_data]
    end

    return new_to_existing_before_on, display_data
  end

  def self.dau_mau domain = 30
    graph_data, display_data = Rails.cache.fetch "stat_dau_mau_domain_#{domain}", :expires_in => 13.minutes do

      user_ids_by_date_raw = Post.social.not_us.not_spam\
        .where("created_at > ?", Date.today - (domain + 31).days)\
        .select(["to_char(posts.created_at, 'YY/MM/DD')", "array_to_string(array_agg(user_id),',')"]).group("to_char(posts.created_at, 'YY/MM/DD')").all

      user_ids_last_24_raw = Post.social.not_us.not_spam\
        .where("created_at > ?", 24.hour.ago)\
        .select(["to_char(posts.created_at, 'YY')", "array_to_string(array_agg(user_id),',')"]).group("to_char(posts.created_at, 'YY')").all

      user_ids_by_date = {}
      user_ids_by_date_raw.each do |post|
        user_ids_by_date[post.to_char] = post.array_to_string.split(',').uniq
      end
      user_ids_last_24 = []
      user_ids_last_24 = user_ids_last_24_raw[0].array_to_string.split(',').uniq unless user_ids_last_24_raw.blank?

      graph_data = {}
      mau = []
      ((Date.today - (domain + 1))..(Date.today - 1)).each do |date|
        datef = date.strftime("%y/%m/%d")
        graph_data[datef] = 0
        dau = 0
        dau = user_ids_by_date[datef].count if user_ids_by_date[datef]
        mau = []
        ((date - 30)..date).each do |ddate|
          ddatef = ddate.strftime("%y/%m/%d")
          mau += user_ids_by_date[ddatef] unless user_ids_by_date[ddatef].blank?
        end
        mau = mau.uniq.count
        graph_data[datef] = dau.to_f / mau.to_f unless mau == 0
      end

      display_data = {}
      display_data[:today] = user_ids_last_24.count.to_f / mau #0.99 #graph_data[Date.today]

      last_7_days = graph_data.reject{|k,v| 8.days.ago > Date.strptime(k, '%y/%m/%d')}.values
      if last_7_days.size > 0
        display_data[:total] = last_7_days.sum / last_7_days.size
      else
        display_data[:total] = 0
      end

      graph_data = Hash[*graph_data.map{|k,v| [Time.parse(k).strftime('%m/%d'), v]}.flatten]
      display_data[:today] = sprintf "%.1f%", display_data[:today] * 100
      display_data[:total] = sprintf "%.1f%", display_data[:total] * 100

      [graph_data, display_data]
    end
    return graph_data, display_data
  end

  def self.daus asker_id = nil, domain = 30
    graph_data, display_data = Rails.cache.fetch "stat_daus_asker_id_#{asker_id}_domain_#{domain}", :expires_in => 17.minutes do
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

      [graph_data, display_data]
    end
    return graph_data, display_data
  end

  def self.econ_engine domain = 30
    econ_engine, display_data = Rails.cache.fetch "stat_econ_engine_domain_#{domain}", :expires_in => 19.minutes do

      @posts_by_date = Post.joins(:user).not_spam.not_us.social\
          .where('provider_post_id IS NOT NULL')\
          .where("in_reply_to_user_id IN (#{Asker.all.collect(&:id).join(",")})")\
          .where("posts.created_at > ?", Date.today - domain)\
          .select(["posts.created_at", :in_reply_to_user_id, :interaction_type, :spam, :autospam, "users.role", :user_id])\
          .group("to_char(posts.created_at, 'YY/MM/DD')")\
          .count('posts.id')

      @econ_engine = []
      @posts_by_date.each{|date, post_count| @econ_engine << [date, post_count] unless date == Date.today.strftime('%y/%m/%d')}

      @econ_engine.sort!{|a,b| a[0] <=> b[0]}
      @econ_engine = @econ_engine.map{|row| [row[0].gsub(/^[0-9]+\//, ""), row[1]]}
      @econ_engine = [['Date', 'Soc. Actions']] + @econ_engine

      display_data = {}
      display_data[:today] = Post.not_spam.not_us.social.where('provider_post_id IS NOT NULL').where("posts.created_at > ?", Time.now - 24.hours).count
      display_data[:month] = Post.not_spam.not_us.social.where('provider_post_id IS NOT NULL').where("posts.created_at > ?", Time.now - 30.days).count

      [@econ_engine, display_data]
    end
    return econ_engine, display_data
  end

  def self.revenue domain = 30
    revenue, display_data = Rails.cache.fetch "stat_revenue_domain_#{domain}", :expires_in => 23.minutes do
      @rate_sheets = RateSheet.where('title IS NOT NULL').includes(:clients => :askers)
      return if @rate_sheets.empty?
      @clients = @rate_sheets.collect{|rs| rs.clients}.flatten.uniq
      @askers_by_rate_sheet = {}
      @clients.each{|c| @askers_by_rate_sheet[c.rate_sheet] = c.askers}
      return if @askers_by_rate_sheet.empty?

      @posts_by_date_by_rate_sheet = {}
      @askers_by_rate_sheet.each do |rate_sheet, askers|
        posts_by_date = Post.not_spam.social.not_us\
            .where("in_reply_to_user_id IN (?)", askers.collect(&:id))\
            .where("created_at > ?", domain.days.ago)\
            .select([:text, "posts.created_at", :in_reply_to_user_id, :interaction_type, :correct, :user_id, :spam, :autospam])\
            .order("posts.created_at ASC")\
            .group_by{|p| p.created_at.strftime('%y/%m/%d')}
        posts_by_date.each do |date, posts|
          @posts_by_date_by_rate_sheet[date] ||= {}
          @posts_by_date_by_rate_sheet[date][rate_sheet] = posts
        end
      end

      @revenue = [['Date'] + @rate_sheets.collect(&:title)]
      @posts_by_date_by_rate_sheet.each do |date, posts_by_rate_sheet|
        next if date == Date.today.strftime('%y/%m/%d')
        revenues_by_rate_sheet = {}
        posts_by_rate_sheet.each do |rate_sheet, posts|
          posts_by_interaction_type = posts.group_by{|p| p.interaction_type}
          rt_revenue = tweet_revenue = 0
          tweet_revenue = posts_by_interaction_type[2].count * rate_sheet.tweet if posts_by_interaction_type[2]
          rt_revenue = posts_by_interaction_type[3].count * rate_sheet.retweet if posts_by_interaction_type[3]

          revenues_by_rate_sheet[rate_sheet] = tweet_revenue + rt_revenue
        end
        @revenue << [date] + @rate_sheets.map{|rs| revenues_by_rate_sheet[rs] || 0 }
      end

      #sort
      title_row = @revenue.shift
      @revenue = [title_row] + @revenue.sort_by{|r|r[0]}.map{|r| [Time.parse(r[0]).strftime('%m/%d')] + r[1..-1]}

      [@revenue, Stat.revenue_display_data(@askers_by_rate_sheet)]
    end
    return revenue, display_data
  end

  def self.revenue_display_data askers_by_rate_sheet
    display_data = {:today => 0, :month => 0}

    @askers_by_rate_sheet.each do |rate_sheet, askers|
      posts = {}
      posts[:today] = Post.not_spam.social.not_us.where("created_at > ?", 24.hours.ago).where("in_reply_to_user_id IN (?)", askers.collect(&:id))
      posts[:month] = Post.not_spam.social.not_us.where("created_at > ?", 30.days.ago).where("in_reply_to_user_id IN (?)", askers.collect(&:id))

      [:today, :month].each do |period|
        posts_by_interaction_type = posts[period].group_by{|p| p.interaction_type}

        rt_revenue = tweet_revenue = 0
        tweet_revenue = posts_by_interaction_type[2].count * rate_sheet.tweet if posts_by_interaction_type[2]
        rt_revenue = posts_by_interaction_type[3].count * rate_sheet.retweet if posts_by_interaction_type[3]
        display_data[period] += tweet_revenue + rt_revenue
      end
    end

    display_data[:today] = sprintf "$%.2f", display_data[:today]
    display_data[:month] = sprintf "$%.2f", display_data[:month]
    display_data
  end

  def self.handle_activity(handle_activity = {}, graph_data = [])
    # y axis label
    # revert active
    title_row = ['Handle']
    User.askers.select([:id, :twi_screen_name]).all.each { |asker| handle_activity[asker.id] = [asker.twi_screen_name] }
    user_grouped_posts = Post.joins(:user).not_spam.not_us.social\
      .where("posts.in_reply_to_user_id IN (?)", User.askers.collect(&:id))\
      .where("posts.created_at > ?", 1.week.ago)\
      .where("interaction_type <> 4")\
      .select([:user_id, :in_reply_to_user_id])\
      .order("posts.created_at DESC")\
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
    graph_data = [["Date", "Wisr answers", "Twitter answers"]]
    wisr_day_grouped_answers = Post.social.not_us.not_spam\
      .where("created_at > ? and correct is not null and posted_via_app = ?", Date.today - domain.days, true)\
      .select(["to_char(created_at, 'MM/DD') as date", "array_to_string(array_agg(user_id),',') as user_ids"])\
      .group("to_char(created_at, 'MM/DD')").all.group_by { |a| a.date }
    twitter_day_grouped_answers = Post.social.not_us.not_spam\
      .where("created_at > ? and correct is not null and posted_via_app = ?", Date.today - domain.days, false)\
      .select(["to_char(created_at, 'MM/DD') as date", "array_to_string(array_agg(user_id),',') as user_ids"])\
      .group("to_char(created_at, 'MM/DD')").all.group_by { |a| a.date }
    ((domain.days.ago.to_date)..Date.today.to_date).each do |date|
      formatted_date = date.strftime("%m/%d")
      # next if day_grouped_answers[formatted_date].blank?
      data = [formatted_date]
      
      [wisr_day_grouped_answers, twitter_day_grouped_answers].each do |day_grouped_answers|
        counts = []
        if day_grouped_answers[formatted_date].nil?
          values = []
        else
          values = day_grouped_answers[formatted_date][0].user_ids.split(",")
        end
        values.each do |e|
          counts << values.count(e)
          values.delete(e)
        end
        
        # avg
        # denom = (counts.size > 0) ? counts.size : 1
        # data << counts.sum / denom

        # median
        data << counts.sort![(counts.length.to_f / 2).floor]
      end

      graph_data << data
    end
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

  def self.lifecycle
    transitions_to_segment_by_day = {}
    [0, 1, 2, 3, 4, 5, 6].each do |to_segment|  
      i = to_segment
      to_segment = nil if to_segment == 0
      transitions_to_segment_by_day[i] = Transition.where(:segment_type => 2, :to_segment => to_segment)\
        .select(["to_char(transitions.created_at, 'YY/MM/DD') as created_at", "array_to_string(array_agg(user_id),',') AS user_ids"])\
        .group("to_char(transitions.created_at, 'YY/MM/DD')")\
        .order('created_at ASC')\
        .group_by{|p| p[:created_at]}\
        .each{|k,r| r.replace r.map{|o| o.user_ids}.join(',').split(',') }
    end
    transitions_to_segment_by_day.each{|k,v|v.each{|kk,vv| transitions_to_segment_by_day[k][kk] = vv.count}}

    data = {}
    transitions_to_segment_by_day.each do |to_seg, transitions_by_day|
      transitions_by_day.each do |date, count|
        data[date - 1.day] ||= {0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0}
        data[date] ||= {0 => 0, 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0}
        data[date][to_seg] = data[date - 1.day][to_seg] + count
      end
    end
    data_r = data.map do |date, seg_counts| 
      denom = seg_counts.values.sum
      puts denom
      denom = 1 if denom == 0
      [date.strftime("%m-%d")] + seg_counts.values.map{|c| c.to_i.to_f/denom}
    end
    data_r = [['Date', 0, 1, 2, 3, 4, 5, 6]] + data_r
  end

  def self.learner_levels
    graph_data = [['learner level', 'users']]
    LEARNER_LEVELS.each do |level|
      next if level == "unengaged"
      graph_data << [level, User.count(:conditions => "learner_level = '#{level}'")]
    end
    return graph_data
  end

  def self.age_v_reengagement_v_response_rate
    #post.where(intention: 'reengage inactive').select(['id']).collect &:id
    reengagement_ids = Post.where(intention: 'reengage inactive').select(["array_to_string(array_agg(id),',') AS ids"]).group('').first.ids.split ","
    reengagement_ids_to_child_ids = Hash[*Post.select(['id', 'in_reply_to_post_id']).where('in_reply_to_post_id IN (?)', reengagement_ids).map{|p| [p.in_reply_to_post_id, p.id]}.flatten]

    user_ids_to_reengagement_dates = Hash[*Post.where(intention: 'reengage inactive')\
      .select(["in_reply_to_user_id", "array_to_string(array_agg(created_at || '--' || id),',') AS created_ats"])\
      .group("in_reply_to_user_id").map{|p| [p.in_reply_to_user_id, p.created_ats]}.flatten]

    user_ids_to_first_post_created_ats = Hash[*Post.not_spam\
      .select(["user_id", "min(created_at) as created_at"])\
      .group("user_id").map{|p| [p.user_id, p.created_at]}.flatten]

    reengagements_and_response_rate_by_age = {}
    user_ids_to_reengagement_dates.each do |user_id, reengagement_dates_with_ids|
      reengagement_dates_with_ids.split(',').each do |reengagement_date_with_id|
        created_at, id = reengagement_date_with_id.split('--')
        id = id.to_i
        created_at = Time.parse(created_at)
        age = ((Time.now - created_at)/1.day).round

        reengagements_and_response_rate_by_age[age] ||= {answered: 0, unanswered: 0, reengagements: 0}
        reengagements_and_response_rate_by_age[age][:reengagements] += 1
        if reengagement_ids_to_child_ids[id].nil?
          reengagements_and_response_rate_by_age[age][:unanswered] += 1
        else
          reengagements_and_response_rate_by_age[age][:answered] += 1
        end
      end
    end
    data = [['Date', 'Reengagements', 'Response rate']]
    reengagements_and_response_rate_by_age.keys.sort.each do |date|
      h = reengagements_and_response_rate_by_age[date]
      response_rate = h[:answered].to_f / (h[:answered] + h[:unanswered])
      data << [date, h[:reengagements], response_rate]
    end
    data
  end

  def self.days_since_active_when_reengaged_v_response_rate
    reengagement_ids = Post.where(intention: 'reengage inactive').select(["array_to_string(array_agg(id),',') AS ids"]).group('').first.ids.split ","
    reengagement_ids_to_child_ids = Hash[*Post.select(['id', 'in_reply_to_post_id']).where('in_reply_to_post_id IN (?)', reengagement_ids).map{|p| [p.in_reply_to_post_id, p.id]}.flatten]
    user_ids_to_reengagement_dates = Hash[*Post.where(intention: 'reengage inactive')\
      .select(["in_reply_to_user_id", "array_to_string(array_agg(EXTRACT(EPOCH FROM created_at) :: bigint || '--' || id),',') AS created_ats"])\
      .group("in_reply_to_user_id").map{|p| [p.in_reply_to_user_id, p.created_ats]}.flatten]

    user_ids_to_posts_as_str = Post.not_spam.not_us.select(['user_id', "array_to_string(array_agg(EXTRACT(EPOCH FROM created_at) :: bigint),',') AS created_ats"]).group('user_id')
    users_with_posts_created_ats = {}
    user_ids_to_posts_as_str.each{|obj| users_with_posts_created_ats[obj.user_id] = obj.created_ats.split(",")}

    days_since_engaged_with_response_rate = {}
    user_ids_to_reengagement_dates.each do |user_id, created_ats_with_ids|
      next if users_with_posts_created_ats[user_id.to_i].nil? # no posts queried probably because the user is one of us
      created_ats_with_ids.split(',').each do |created_at_with_id|
        created_at, id = created_at_with_id.split('--')
        created_at = created_at.to_f
        id = id.to_i
        most_recent_post_created_at = users_with_posts_created_ats[user_id.to_i].map{|x|x.to_i}.reject{|t| t.to_i >= created_at}.max
        next if most_recent_post_created_at.nil? # no previous post

        days_since_active_when_reengaged = ((created_at - most_recent_post_created_at)/86400).round

        days_since_engaged_with_response_rate[days_since_active_when_reengaged] ||= {answered: 0, unanswered: 0, reengagements: 0}
        days_since_engaged_with_response_rate[days_since_active_when_reengaged][:reengagements] += 1
        if reengagement_ids_to_child_ids[id.to_i].nil?
          days_since_engaged_with_response_rate[days_since_active_when_reengaged][:unanswered] += 1
        else
          days_since_engaged_with_response_rate[days_since_active_when_reengaged][:answered] += 1
        end
      end
    end

    data = [['Date', 'Reengagements', 'Response rate']]
    days_since_engaged_with_response_rate.keys.sort.each do |day_count|
      next if day_count > 30
      h = days_since_engaged_with_response_rate[day_count]
      response_rate = h[:answered].to_f / (h[:answered] + h[:unanswered])
      data << [day_count, h[:reengagements], response_rate]
    end
    data
  end

  def self.days_since_active_v_number_of_reengagement_attempts
    user_ids_to_reengagement_dates = Hash[*Post.where(intention: 'reengage inactive')\
      .select(["in_reply_to_user_id", "array_to_string(array_agg(created_at),',') AS created_ats"])\
      .group("in_reply_to_user_id").map{|p| [p.in_reply_to_user_id, p.created_ats]}.flatten]

    user_ids_to_last_active = Hash[*Post.not_us.not_spam.social\
      .where('correct IS NOT NULL OR autocorrect IS NOT NULL')\
      .select(["user_id","max(created_at) AS most_recent_created_at"]).group('user_id').map{|p|[p.user_id, Time.parse(p.most_recent_created_at)]}.flatten]

    inactive_users = User.select(["array_to_string(array_agg(id),',') AS ids"]).where("users.activity_segment = 7").first.ids.split(",").map{|id| id.to_i}

    data = [] # add series with tooltips in js
    user_ids_to_last_active.each do |user_id, last_interaction_at|
      next if user_ids_to_reengagement_dates[user_id].nil?
      reengagement_attempts = user_ids_to_reengagement_dates[user_id].split(',').map{|created_at|Time.parse(created_at)}
      reengagement_attempts_count = reengagement_attempts.reject{|date| date < last_interaction_at}.count

      next if (Time.now - last_interaction_at) <= 0
      if inactive_users.index(user_id).nil?
        data << [(Time.now - last_interaction_at)/1.day, reengagement_attempts_count, user_id, nil, nil]
      else
        data << [(Time.now - last_interaction_at)/1.day, nil, nil, reengagement_attempts_count, user_id]
      end

    end
    data
  end

  def self.age_v_days_since_active
    user_ids_to_last_active = Hash[*Post.not_us.not_spam\
      .where("created_at > ?", Time.now - 180.days)\
      .where("correct IS NOT NULL")\
      .select(["user_id","max(created_at) AS most_recent_created_at"]).group('user_id').map{|p|[p.user_id, Time.parse(p.most_recent_created_at)]}.flatten]

    user_ids_to_first_post_created_ats = Hash[*Post.not_spam.not_us\
      .select(["user_id", "min(created_at) as first_active_at"])\
      .group("user_id").map{|p| [p.user_id, Time.parse(p.first_active_at)]}.flatten]

    data = [['Age', 'Days inactive']]
    user_ids_to_first_post_created_ats.each do |user_id, first_active_at|
      next if user_ids_to_last_active[user_id].nil?
      data << [(Time.now - first_active_at)/1.day, (Time.now - user_ids_to_last_active[user_id])/1.day]
    end
    data
  end

  def self.viral_actions_v_new_users domain = 30

    # new users by day
    @user_ids_to_first_active = Post.not_us.not_spam\
      .where("correct IS NOT NULL")\
      .select(["user_id","to_char(min(created_at), 'YY/MM/DD') AS most_recent_created_at"])\
      .group('user_id').map{|p|[p.most_recent_created_at, p.user_id]}.group_by{|r|r[0]}

    # viral actions by day
    @viral_actions_by_date = Post.joins(:user).not_spam.not_us.social\
      .where('provider_post_id IS NOT NULL')\
      .where("in_reply_to_user_id IN (#{Asker.all.collect(&:id).join(",")})")\
      .where("posts.created_at > ?", Date.today - domain)\
      .select(["posts.created_at", :in_reply_to_user_id, :interaction_type, :spam, :autospam, "users.role", :user_id])\
      .group("to_char(posts.created_at, 'YY/MM/DD')")\
      .count('posts.id')

    data = [['Date', 'Ratio']]
    @viral_actions_by_date.keys.sort.each do |date|
      viral_actions = @viral_actions_by_date[date] || 1
      new_users = @user_ids_to_first_active[date].count || 0
      data << [Time.parse(date).strftime('%m/%d'), (new_users.to_f / viral_actions)]
    end
    data
  end

  def self.experiment_summary experiment_name
    case experiment_name
    when "post aggregate activity"
      Stat.post_aggregate_activity_summary()  
    end
  end

  def self.post_aggregate_activity_summary
    experiment_data = Stat.get_alternative_grouped_user_ids_by_experiment "post aggregate activity"
    aggregate_post_ids = Post.where("intention = 'post aggregate activity'")\
      .where("created_at > ? and in_reply_to_user_id in (?)", experiment_data[:start_time], experiment_data[:alternatives]["true"]).collect(&:id)
    grade_post_ids = Post.where("intention = 'grade'")\
      .where("created_at > ? and in_reply_to_user_id in (?)", experiment_data[:start_time], experiment_data[:alternatives]["false"]).collect(&:id)

    aggregate_count = Post.retweet.where("in_reply_to_post_id in (?) and created_at > ?", aggregate_post_ids, experiment_data[:start_time]).size
    grade_count = Post.retweet.where("in_reply_to_post_id in (?) and created_at > ?", grade_post_ids, experiment_data[:start_time]).size

    puts "aggregate post retweets = #{aggregate_count}"
    puts "grade post retweets = #{grade_count}"
  end

  def self.get_alternative_grouped_user_ids_by_experiment experiment_name, experiment_data = {:alternatives => {}}
    ab_user = Split::RedisStore.new(Split.redis) 
    experiment = Split::Experiment.find(experiment_name)
    experiment_data[:start_time] = experiment.start_time
    User.all.each do |user|
      ab_user.set_id(user.id)
      if alternative = ab_user.get_key(experiment.key)
        experiment_data[:alternatives][alternative] ||= []
        experiment_data[:alternatives][alternative] << user.id 
      end
    end
    experiment_data
  end
end