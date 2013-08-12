class Stat < ActiveRecord::Base
  belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'

  def self.followers_count
    Rails.cache.fetch "stats_followers count", :expires_in => 1.hour do
      Asker.all.collect {|a| a.followers.collect(&:id) }.flatten.uniq.size
    end
  end

  ##
  ## Growth functions
  ##

  def self.graph_paulgraham domain = 30
    ratios_running_avg, display_data = Rails.cache.fetch "stat_paulgraham_domain_#{domain}", :expires_in => 17.minutes do
      ratios_running_avg = pg_ratios_with_running_avg(pg_ratios domain)
      display_data = {
        :today => ratios_running_avg.last[1],
        :total => ratios_running_avg.last[2]
      }
      display_data[:today] = sprintf "%.1f%", display_data[:today] * 100
      display_data[:total] = sprintf "%.1f%", display_data[:total] * 100
      [ratios_running_avg, display_data]
    end
    return [ratios_running_avg, display_data]
  end

  def self.pg_ratios domain = 30
    ratios = {}
    waus = Stat.paus_by_date(Stat.dau_ids_by_date(domain), 7)
    waus.each do |d,count|
      date_formated = Date.parse(d)
      prev_week_formated = (date_formated - 7.days).strftime
      next if waus[prev_week_formated] == 0 or waus[prev_week_formated].nil?
      ratios[d] = waus[d].to_f / waus[prev_week_formated] - 1
    end
    ratios.sort #convert from hash to 2x array
  end

  def self.pg_ratios_with_running_avg ratios, period = 30
    ratios_with_avg = []
    ratios.each_with_index do |ratio, i|
      ii = i - (period - 1)
      ii = 0 if ii < 0
      sum = 0
      (ii..i).to_a.each do |j|
        sum += ratios[j][1]
      end
      avg = sum.to_f / (i - ii)
      avg = 0 if i == 0
      ratios_with_avg << ratios[i] + [avg]
    end
    ratios_with_avg
  end

  def self.dau_ids_by_date domain = 30
    user_ids_by_date_raw = Post.social.not_us.not_spam\
      .where("created_at > ?", Date.today - (domain + 31).days)\
      .where("created_at < ?", Date.today)\
      .select(["to_char(posts.created_at, 'YYYY-MM-DD')", "array_to_string(array_agg(user_id),',')"]).group("to_char(posts.created_at, 'YYYY-MM-DD')").to_a

    user_ids_by_date = {}
    user_ids_by_date_raw.each do |post|
      user_ids_by_date[post.to_char] = post.array_to_string.split(',').uniq
    end
    user_ids_by_date
  end


  def self.paus_by_date daus, period = 7
    paus = {}
    daus.sort.each do |r|
      date = r[0]
      catch :missing_day do
        ids = []
        start_date_formated = Date.parse(date)
        ((start_date_formated - (period - 1).days)..start_date_formated).to_a.each do |rdate|
          rdate_formatted = rdate.strftime
          throw :missing_day if daus[rdate_formatted].nil?
          ids += daus[rdate_formatted] unless daus[rdate_formatted].empty?
        end
        paus[date] = ids.uniq.count
      end
    end
    paus
  end

  ###
  ### DAU MAU
  ###

  def self.graph_dau_mau domain = 30
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

  def self.month_summary asker_id = nil, domain = 30
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

  def self.graph_econ_engine domain = 30
    econ_engine, display_data = Rails.cache.fetch "stat_econ_engine_domain_#{domain}", :expires_in => 19.minutes do
      posts_by_date = Post.joins(:user).not_spam.not_us.social\
        .where('provider_post_id IS NOT NULL')\
        .where("in_reply_to_user_id IN (#{Asker.all.collect(&:id).join(",")})")\
        .where("posts.created_at > ?", Date.today - domain)\
        .select(["posts.created_at", :in_reply_to_user_id, :interaction_type, :spam, :autospam, "users.role", :user_id])\
        .group("to_char(posts.created_at, 'YY/MM/DD')")\
        .count('posts.id')

      econ_engine = []
      posts_by_date.each{|date, post_count| econ_engine << [date, post_count] unless date == Date.today.strftime('%y/%m/%d')}
      econ_engine.sort!{|a,b| a[0] <=> b[0]}

      econ_engine = econ_engine.map{|row| [row[0].gsub(/^[0-9]+\//, ""), row[1]]}
      econ_engine = [['Date', 'Soc. Actions']] + econ_engine

      display_data = {}
      display_data[:today] = Post.not_spam.not_us.social.where('provider_post_id IS NOT NULL').where("posts.created_at > ?", Time.now - 24.hours).count
      display_data[:total] = Post.not_spam.not_us.social.where('provider_post_id IS NOT NULL').where("posts.created_at > ?", Time.now - 30.days).count

      [econ_engine, display_data]
    end
    return econ_engine, display_data
  end


  def self.graph_quality_response domain = 30, running_average_day_count = 7
    data = Rails.cache.fetch "stat_quality_response_domain_#{domain}", :expires_in => 19.minutes do
      data = [["Date", "Quality Response %", "#{running_average_day_count} Day Avg"]]
      today_stat = "0%"
      total_stat = []
      days_ago = (domain + running_average_day_count).days.ago

      moderated_post_counts_by_date = Post.where("created_at > ?", days_ago)\
        .where("moderation_trigger_type_id is not null")\
        .select(["to_char(posts.updated_at, 'YYYY-MM-DD')"])\
        .group("to_char(posts.updated_at, 'YYYY-MM-DD')")\
        .count
      autocorrected_post_counts_by_date = Post.where("created_at > ?", days_ago)\
        .where("autocorrect is not null")\
        .select(["to_char(posts.updated_at, 'YYYY-MM-DD')"])\
        .group("to_char(posts.updated_at, 'YYYY-MM-DD')")\
        .count 
      autocorrected_and_moderated_post_counts_by_date = Post.where("created_at > ?", days_ago)\
        .where("moderation_trigger_type_id is not null")\
        .where("autocorrect is not null")\
        .select(["to_char(posts.updated_at, 'YYYY-MM-DD')"])\
        .group("to_char(posts.updated_at, 'YYYY-MM-DD')")\
        .count
      correctly_autograded_as_correct_post_counts_by_date = Post.where("created_at > ?", days_ago)\
        .where("moderation_trigger_type_id is not null")\
        .where("autocorrect = true")\
        .where("correct = true")\
        .select(["to_char(posts.updated_at, 'YYYY-MM-DD')"])\
        .group("to_char(posts.updated_at, 'YYYY-MM-DD')")\
        .count
      correctly_autograded_as_incorrect_post_counts_by_date = Post.where("created_at > ?", days_ago)\
        .where("moderation_trigger_type_id is not null")\
        .where("autocorrect = false")\
        .where("correct = false")\
        .select(["to_char(posts.updated_at, 'YYYY-MM-DD')"])\
        .group("to_char(posts.updated_at, 'YYYY-MM-DD')")\
        .count

      percent_quality_history = []
      ((Date.today - (domain + running_average_day_count).days)..(Date.today - 1.day)).each do |date|
        datef = date.to_s
        moderated_post_count = moderated_post_counts_by_date[datef] || 0
        autocorrected_and_moderated_post_count = (autocorrected_and_moderated_post_counts_by_date[datef] || 0)
        total_post_count = (moderated_post_counts_by_date[datef] || 0) + (autocorrected_post_counts_by_date[datef] || 0)

        if autocorrected_and_moderated_post_count > 0
          autocorrected_quality_response_count = (correctly_autograded_as_correct_post_counts_by_date[datef] || 0) + (correctly_autograded_as_incorrect_post_counts_by_date[datef] || 0)
          autocorrected_percent_quality = (autocorrected_quality_response_count.to_f / autocorrected_and_moderated_post_count.to_f)
          quality_autocorrected_post_count = (autocorrected_post_counts_by_date[datef] || 0) * autocorrected_percent_quality
          quality_response_count = quality_autocorrected_post_count + moderated_post_count
        else
          quality_response_count = moderated_post_count
        end

        percent_quality = quality_response_count.to_f / total_post_count.to_f
        percent_quality_history << percent_quality

        if date >= (Date.today - domain.days)
          moving_average = percent_quality_history[(-running_average_day_count)..-1].sum / running_average_day_count
          data << [datef, percent_quality, moving_average]
          today_stat = sprintf("%.1f%", percent_quality * 100) if date == Date.yesterday
          total_stat << percent_quality if (date > (Date.yesterday - 1.week))
        end
      end
      total_stat = sprintf "%.1f%", (total_stat.sum / total_stat.size) * 100
      [data, {today: today_stat, total: total_stat}]
    end
  end

  def self.graph_timely_response domain = 30
    data = Rails.cache.fetch "stat_timely_response_domain_#{domain}", :expires_in => 23.minutes do
      def self.replies(domain, end_time)
        replies = Post.not_spam.not_us.where("posts.posted_via_app = ?", false)\
          .where('requires_action = ?', false)\
          .where("posts.created_at > ?", end_time - domain)\
          .where("posts.created_at < ?", end_time)\

        good_replies = replies.where("(posts.updated_at - posts.created_at < interval '3 hours')")\
          .select(["to_char(posts.created_at, 'YYYY-MM-DD')"]).group("to_char(posts.created_at, 'YYYY-MM-DD')").count
        ok_replies = replies.where("(posts.updated_at - posts.created_at > interval '3 hours')")\
          .where("(posts.updated_at - posts.created_at < interval '24 hours')")\
          .select(["to_char(posts.created_at, 'YYYY-MM-DD')"]).group("to_char(posts.created_at, 'YYYY-MM-DD')").count
        slow_replies = replies.where("(posts.updated_at - posts.created_at > interval '24 hours')")\
          .select(["to_char(posts.created_at, 'YYYY-MM-DD')"]).group("to_char(posts.created_at, 'YYYY-MM-DD')").count
        no_replies = Post.mentions.not_spam.not_us.where("posts.posted_via_app = ?", false)\
          .requires_action\
          .joins("INNER JOIN posts as parents on parents.id = posts.in_reply_to_post_id")\
          .where("parents.question_id IS NOT NULL")\
          .where("posts.created_at > ?", end_time - domain)\
          .where("posts.created_at < ?", end_time)\
          .select(["to_char(posts.created_at, 'YYYY-MM-DD')"]).group("to_char(posts.created_at, 'YYYY-MM-DD')").count
        return [good_replies, ok_replies, slow_replies, no_replies]
      end

      good_replies, ok_replies, slow_replies, no_replies = replies domain.days, Date.today
      data = [["Date", "Good Reply", "OK replies", "Slow Reply", "No Reply"]]
      total_stat = []
      today_stat = 0
      ((Date.today - domain.days)..(Date.today - 1.day)).each do |date|
        datef = date.to_s

        good_replies[datef] ||= 0
        ok_replies[datef] ||= 0
        slow_replies[datef] ||= 0
        no_replies[datef] ||= 0

        total = (good_replies[datef] + ok_replies[datef] + slow_replies[datef]  + no_replies[datef] ).to_f
        total = 1 if total < 1
        good_normalized = good_replies[datef] / total
        ok_normalized = ok_replies[datef] / total
        slow_normalized = slow_replies[datef] / total
        no_normalized = no_replies[datef] / total

        data << [datef, good_normalized, ok_normalized, slow_normalized, no_normalized]
        # today_stat = sprintf "%.1f%", good_normalized * 100 if date == Date.today
        total_stat << good_normalized if date > Date.today - 7.days
      end

      good_replies, ok_replies, slow_replies, no_replies = replies 24.hours, Time.now
      today_stat = good_replies.values.sum / (good_replies.values.sum  + ok_replies.values.sum + slow_replies.values.sum  + no_replies.values.sum ).to_f
      today_stat = sprintf "%.1f%", today_stat * 100
      total_stat = sprintf "%.1f%", (total_stat.sum / total_stat.size) * 100
      [data, {today: today_stat, total: total_stat}]
    end
    data
  end

  def self.graph_timely_response_by_handle domain = 30
    graph_data = Rails.cache.fetch "stat_graph_timely_response_by_handle_#{domain}", :expires_in => 19.minutes do
      # group_size = 500
      group_size = 5

      follower_counts_by_asker_id = Asker.includes(:follower_relationships)\
        .published\
        .references(:follower_relationships)\
        .group('relationships.followed_id')\
        .count('relationships.id')\
        .sort_by {|k, v| v }.reverse

      follower_count_grouped_askers = {}
      follower_count_grouped_askers[0] = follower_counts_by_asker_id[0..group_size]
      follower_count_grouped_askers[1] = follower_counts_by_asker_id[-group_size..-1]

      # follower_count_grouped_askers = Asker.includes(:follower_relationships)\
      #   .published\
      #   .references(:follower_relationships)\
      #   .group('relationships.followed_id')\
      #   .count('relationships.id')\
      #   .group_by {|e| (e[1]/group_size.to_f).to_i}

      # follower_count_grouped_askers.each { |k, v| follower_count_grouped_askers.delete(k) if (k > 0 and k < (follower_count_grouped_askers.keys.max)) }
      # follower_count_grouped_askers.each { |k, v| follower_count_grouped_askers.delete(k) if k > 4 }

      title_row = ["Date"]
      # follower_count_grouped_askers.keys.sort.each {|k| title_row << "#{k * group_size} - #{(k + 1) * group_size}" }
      title_row << "Smallest #{group_size} handles"
      title_row << "Largest #{group_size} handles"
      data = [title_row]

      follower_count_grouped_askers = follower_count_grouped_askers.sort
      asker_ids_by_group = {}
      follower_count_grouped_askers.each {|asker_group| asker_group[1].each { |asker| asker_ids_by_group[asker[0]] = asker_group[0] }}

      replies = Post.not_spam.not_us.where("posts.posted_via_app = ?", false)\
        .where('in_reply_to_user_id in (?)', asker_ids_by_group.keys)\
        .where('requires_action = ?', false)\
        .where("posts.created_at > ?", Date.today - domain.days)\
        .where("posts.created_at < ?", Date.today)

      replies_by_date = replies.group_by { |p| p.created_at.strftime("%Y-%m-%d") }
      ok_replies_by_date = replies.where("(posts.updated_at - posts.created_at < interval '12 hours')").group_by{ |p| p.created_at.strftime("%Y-%m-%d") }

      ((Date.today - domain.days)..(Date.today - 1.day)).each do |date|
        row = []
        datef = date.to_s
        row << datef
        follower_count_grouped_askers.each do |asker_group|
          asker_ids = asker_group[1].collect {|e| e[0]}
          reply_count_for_group = replies_by_date[datef].count {|p| asker_ids.include?(p.in_reply_to_user_id) }
          ok_reply_count_for_group = ok_replies_by_date[datef].count {|p| asker_ids.include?(p.in_reply_to_user_id) }
          row << (reply_count_for_group > 0 ? ((ok_reply_count_for_group.to_f / reply_count_for_group) * 100) : 100)
        end
        data << row
      end
      data
    end
    graph_data
  end

  def self.graph_content_audit domain = 30
    data = [['Date', 'Publishable', 'Needs Edits']]
    domain = 30
    question_count = Question.where('created_at < ?', domain.days.ago).count
    questions_added_per_day = Question.where('created_at > ?', domain.days.ago).group("to_char(created_at, 'YYYY-MM-DD')").count  
    audited_questions = Question.where('publishable is not null or needs_edits is not null')
    (Date.today - (domain + 1).days..Date.today).each do |date|
      datef = date.to_s
      question_count += questions_added_per_day[datef] || 0
      publishable_count = (audited_questions.select { |q| (q.updated_at < date and q.publishable == true) }.count / question_count.to_f) * 100
      needs_edits_count = (audited_questions.select { |q| (q.updated_at < date and q.needs_edits == true) }.count / question_count.to_f) * 100
      data << [datef, publishable_count, needs_edits_count]
    end
    data
  end

  def self.graph_handle_activity domain = 30, handle_activity = {}, graph_data = []
    # y axis label
    # revert active
    title_row = ['Handle']
    User.askers.select([:id, :twi_screen_name]).all.each { |asker| handle_activity[asker.id] = [asker.twi_screen_name.gsub('QuizMe', '').gsub('PrepMe', '').gsub('SAThabit_', '').gsub('sathabit_', '').gsub('Quiz', '')] }
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
    return graph_data
  end

	def self.graph_cohort grouped_posts = {}, graph_data = []
    domain = 8.weeks.ago
    title_row = ["Week"]
    domain_posts = Post.joins(:user)\
      .not_spam\
      .not_us\
      .social\
      .where("posts.created_at > ?", domain)\
      .select("to_char(users.created_at, 'MM/W') as week, posts.created_at, posts.user_id")
    weeks = domain_posts.order("users.created_at ASC").uniq_by(&:week).collect {|p| p.week}
    graph_data << (title_row += weeks)
    date_grouped_posts = domain_posts.order("posts.created_at ASC").group_by { |p| p.created_at.to_date.to_s }
    (domain.to_date..Date.today.to_date).each do |date|
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

  def self.graph_users_per_day(domain = 60)
    domain = 75
    User.where('created_at > ?', domain.days.ago)\
      .group("to_char(created_at, 'MM/DD')")\
      .count\
      .sort\
      .insert(["Date", "New users"])
  end

  def self.graph_questions_answered(domain = 60)
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

  def self.graph_ugc domain = 30
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

  def self.graph_answer_source domain = 30
    graph_data = [["Date", "Wisr", "Twitter"]]
    off_site = Post.where("created_at > ? and correct is not null and posted_via_app = ?", domain.days.ago, false)\
      .group("to_char(created_at, 'MM-DD')")\
      .count
    on_site = Post.where("created_at > ? and correct is not null and posted_via_app = ?", domain.days.ago, true)\
      .group("to_char(created_at, 'MM-DD')")\
      .count
    ((domain.days.ago.to_date)..Date.today.to_date).each do |date|
      formatted_date = date.strftime("%m-%d")
      data = [formatted_date]
      data << (on_site[formatted_date] || 0)
      data << (off_site[formatted_date] || 0)
      graph_data << data
    end
    return graph_data
  end

  def self.graph_lifecycle domain = 30
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

  def self.graph_learner_levels domain = 30
    graph_data = [['learner level', 'users']]
    LEARNER_LEVELS.each do |level|
      next if level == "unengaged"
      graph_data << [level, User.count(:conditions => "learner_level = '#{level}'")]
    end
    return graph_data
  end

  def self.graph_age_v_reengagement_v_response_rate domain = 30
    #post.where(intention: 'reengage inactive').select(['id']).collect &:id
    reengagement_ids = Post.reengage_inactive.select(["array_to_string(array_agg(id),',') AS ids"]).group('').first.ids.split ","
    reengagement_ids_to_child_ids = Hash[*Post.select(['id', 'in_reply_to_post_id']).where('in_reply_to_post_id IN (?)', reengagement_ids).map{|p| [p.in_reply_to_post_id, p.id]}.flatten]

    user_ids_to_reengagement_dates = Hash[*Post.reengage_inactive\
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

  def self.graph_days_since_active_when_reengaged_v_response_rate domain = 30
    reengagement_ids = Post.reengage_inactive.select(["array_to_string(array_agg(id),',') AS ids"]).group('').first.ids.split ","
    reengagement_ids_to_child_ids = Hash[*Post.select(['id', 'in_reply_to_post_id']).where('in_reply_to_post_id IN (?)', reengagement_ids).map{|p| [p.in_reply_to_post_id, p.id]}.flatten]
    user_ids_to_reengagement_dates = Hash[*Post.reengage_inactive\
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

  def self.graph_days_since_active_v_number_of_reengagement_attempts domain = 30
    user_ids_to_reengagement_dates = Hash[*Post.reengage_inactive\
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

  def self.graph_age_v_days_since_active domain = 30
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

  def self.graph_viral_actions_v_new_users domain = 30

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

  def self.graph_avg_lifecycle domain = 30
    user_ids_to_last_active = Hash[*Post.not_us.not_spam\
      .select(["user_id","max(created_at) AS most_recent_created_at"]).group('user_id').map{|p|[p.user_id, Time.parse(p.most_recent_created_at)]}.flatten]
      # .where("correct IS NOT NULL")\
      # .where("created_at > ?", Time.now - 180.days)\

    user_ids_to_first_post_created_ats = Hash[*Post.not_spam.not_us\
      .select(["user_id", "min(created_at) as first_active_at"])\
      .group("user_id").map{|p| [p.user_id, Time.parse(p.first_active_at)]}.flatten]

    avg_lifecycle_by_birth = {}
    med_lifecycle_by_birth = {}
    lifecycles_by_birth = {}
    user_ids_to_first_post_created_ats.each do |user_id, birth|
      next if birth < Date.today - domain.days

      birth_date = Time.at((birth.to_f / 1.day).round * 1.day)
      lifecycles_by_birth[birth_date] ||= []
      diff = user_ids_to_last_active[user_id] - birth
      lifecycles_by_birth[birth_date] << diff / 1.day
    end
    lifecycles_by_birth.each do |birth, lifecycles| 
      avg_lifecycle_by_birth[birth] =  lifecycles.sum / lifecycles.count.to_f

      arr = lifecycles
      len = arr.length
      sorted = arr.sort
      median = len % 2 == 1 ? sorted[len/2] : (sorted[len/2 - 1] + sorted[len/2]).to_f / 2
      med_lifecycle_by_birth[birth] =  median
    end

    data = [['Date', 'Avg', 'Med']]
    avg_lifecycle_by_birth.keys.sort.each do |birth|
      data << [birth.strftime("%m-%d"), avg_lifecycle_by_birth[birth], med_lifecycle_by_birth[birth]]
    end
    data
  end

  def self.graph_user_moderated_posts domain = 30
    consensus_mods_by_date = Post.moderated_by_consensus\
      .where('created_at > ?', (Date.today - (domain + 1).days))\
      .group("to_char(posts.updated_at, 'YYYY-MM-DD')").count
    above_advanced_mods_by_date = Post.moderated_by_above_advanced\
      .where('created_at > ?', (Date.today - (domain + 1).days))\
      .group("to_char(posts.updated_at, 'YYYY-MM-DD')").count
    tiebreaker_mods_by_date = Post.moderated_by_tiebreaker\
      .where('created_at > ?', (Date.today - (domain + 1).days))\
      .group("to_char(posts.updated_at, 'YYYY-MM-DD')").count

    data = [['Day', 'Consensus', 'Tiebreaker', 'Above Advanced']]
    (Date.today - (domain + 1).days..Date.today).each do |date|
      datef = Time.parse(date.to_s).strftime("%m-%d")
      date = date.to_s
      consensus_mods_count = consensus_mods_by_date[date] || 0
      above_advanced_mods_count = above_advanced_mods_by_date[date] || 0
      tiebreaker_mods_count = tiebreaker_mods_by_date[date] || 0
      data << [datef, consensus_mods_count, above_advanced_mods_count, tiebreaker_mods_count]
    end
    data
  end

  def self.graph_moderations_count domain = 30
    post_moderations_by_date = Moderation.where('post_id is not null')\
      .where('created_at > ?', (Date.today - (domain + 1).days))\
      .group("to_char(updated_at, 'YYYY-MM-DD')").count      

    question_moderations_by_date = Moderation.where('question_id is not null')\
      .where('created_at > ?', (Date.today - (domain + 1).days))\
      .group("to_char(updated_at, 'YYYY-MM-DD')").count      

    data = [['Date', 'Post', 'Question']]
    (Date.today - (domain + 1).days..Date.today).each do |date|
      datef = Time.parse(date.to_s).strftime("%m-%d")
      date = date.to_s
      post_moderations_count = post_moderations_by_date[date] || 0
      question_moderations_count = question_moderations_by_date[date] || 0
      data << [datef, post_moderations_count, question_moderations_count]
    end
    data
  end

  def self.graph_moderators_count domain = 30
    moderations_by_date = Moderation.where('created_at > ?', (Date.today - (domain + 1).days))\
      .select([:updated_at])\
      .group("to_char(updated_at, 'YYYY-MM-DD')").count('distinct(user_id)')

    data = [['Date', 'Count']]
    (Date.today - (domain + 1).days..Date.today).each do |date|
      datef = Time.parse(date.to_s).strftime("%m-%d")
      date = date.to_s
      moderations_count = moderations_by_date[date] || 0
      data << [datef, moderations_count]
    end
    data
  end

  def self.graph_average_time_to_publish domain = 60
    data = [['Date', 'Avg. Days to Publish']]
    domain = 60; period = 7
    user_submitted_questions = Question.not_us\
      .where('updated_at > ?', (domain + period).days.ago)\
      .approved
    (Date.today - (domain + 1).days..Date.today).each do |date|
      questions = user_submitted_questions.select { |q| (q.updated_at < date) and (q.updated_at > (date - period.days)) }
      days_to_publish_questions = questions.collect { |q| (q.updated_at - q.created_at) / 60 / 60 / 24 } 
      data << [date.to_s, (days_to_publish_questions.sum / days_to_publish_questions.count)]
    end
    data
  end

  def self.graph_percent_published domain = 60
    data = [['Date', 'Percent handled', 'Percent published']]
    domain = 60; period = 30
    user_submitted_questions = Question.not_us\
      .where('created_at > ?', (domain + period).days.ago)
    (Date.today - (domain + 1).days..Date.today).each do |date|
      questions = user_submitted_questions.select { |q| (q.created_at < date) and (q.created_at > (date - period.days)) }
      published_count = questions.count { |q| q.status == 1 }
      handled_count = questions.count { |q| q.status == 1 or q.status == -1 }
      data << [date.to_s, ((handled_count / questions.count.to_f) * 100), ((published_count / questions.count.to_f) * 100)]
    end
    data
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