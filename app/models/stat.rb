class Stat < ActiveRecord::Base
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  def self.followers_count
    Rails.cache.fetch "stats_followers count", :expires_in => 1.hour do
      Asker.all.collect {|a| a.followers.collect(&:id) }.flatten.uniq.size
    end
  end

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
    user_ids_by_date_raw = Post.not_us.not_spam.
      where("created_at > ?", Date.today - (domain + 31).days).
      where("created_at < ?", Date.today).
      select(["to_char(posts.created_at, 'YYYY-MM-DD') as date_str", 
               "array_to_string(array_agg(user_id),',') as user_ids_str"]).
      group("date_str").to_a

    user_ids_by_date = {}
    user_ids_by_date_raw.each do |post|
      user_ids_by_date[post.date_str] = post.user_ids_str.split(',').uniq
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
        ((start_date_formated - (period-1).days)..start_date_formated).to_a.each do |rdate|
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
      user_ids_by_date = Stat.dau_ids_by_date domain
      user_ids_last_24 = Stat.active_user_during_period 1.day.ago

      graph_data = {}
      mau = []
      ((Date.today - (domain + 1))..(Date.today - 1)).each do |date|
        datef = date.strftime("%Y-%m-%d")
        graph_data[datef] = 0
        dau = 0
        dau = user_ids_by_date[datef].count if user_ids_by_date[datef]
        mau = []
        ((date - 30)..date).each do |ddate|
          ddatef = ddate.strftime("%Y-%m-%d")
          mau += user_ids_by_date[ddatef] unless user_ids_by_date[ddatef].blank?
        end
        mau = mau.uniq.count
        graph_data[datef] = dau.to_f / mau.to_f unless mau == 0
      end

      display_data = {}
      display_data[:today] = user_ids_last_24.count.to_f / mau #0.99 #graph_data[Date.today]

      last_7_days = graph_data.reject{|k,v| 8.days.ago > Date.strptime(k, '%Y-%m-%d')}.values
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

  def self.active_user_during_period start_time, end_time = Time.now
    post_user_ids_last_24_raw = Post.social.not_us.not_spam.
      where("created_at > ?", 24.hour.ago).
      select(["to_char(posts.created_at, 'YY')", "array_to_string(array_agg(user_id),',')"]).
      group("to_char(posts.created_at, 'YY')").all

    moderation_user_ids_last_24_raw = Moderation.where("created_at > ?", 24.hour.ago).
      select(["to_char(moderations.created_at, 'YY/MM/DD')", "array_to_string(array_agg(user_id),',')"]).
      group("to_char(moderations.created_at, 'YY/MM/DD')").all

    question_ids_last_24_raw = Question.not_us.
      where("created_at > ?", 24.hour.ago).
      select(["to_char(questions.created_at, 'YY/MM/DD')", "array_to_string(array_agg(user_id),',') as user_ids"]).
      group("to_char(questions.created_at, 'YY/MM/DD')").all        

    user_ids_last_24 = []
    user_ids_last_24 << post_user_ids_last_24_raw[0].array_to_string.split(',').uniq unless post_user_ids_last_24_raw.blank?
    user_ids_last_24 << moderation_user_ids_last_24_raw[0].array_to_string.split(',').uniq unless moderation_user_ids_last_24_raw.blank?
    user_ids_last_24 << question_ids_last_24_raw[0].user_ids.split(',').uniq unless question_ids_last_24_raw.blank?
    user_ids_last_24.flatten.uniq
  end

  def self.month_summary asker_id = nil, domain = 30
    display_data = {}
    user_ids_by_date = Post.not_spam.not_us\
        .select(["to_char(posts.created_at, 'MM/DD') as created_at", "user_id", "interaction_type", "correct"])\
        .where("created_at > ? and created_at < ?", Date.today - (domain + 1).days, Date.today)\
        .order("created_at ASC")\
        .group_by { |post| post.created_at }

    moderation_user_ids_by_date = Moderation.where("created_at > ?", domain.days.ago)\
      .select(["to_char(moderations.created_at, 'MM/DD') as created_at", "array_to_string(array_agg(user_id),',') as user_ids"])\
      .group("to_char(moderations.created_at, 'MM/DD')").all.group_by{ |m| m.created_at }

    question_user_ids_by_date = Question.not_us.where("created_at > ?", domain.days.ago)\
      .select(["to_char(questions.created_at, 'MM/DD') as created_at", "array_to_string(array_agg(user_id),',') as user_ids"])\
      .group("to_char(questions.created_at, 'MM/DD')").all.group_by{ |q| q.created_at }


    display_data[:today] = Post.social.not_spam.not_us.where("created_at > ?", 24.hours.ago).count("distinct user_id")
    display_data[:total] = Post.social.not_spam.not_us.where("created_at > ?", (24*domain).hours.ago).count("distinct user_id")

    graph_data = {}
    user_ids_by_date.each do |date, posts|
       ids = posts.select{ |p| !p.correct.nil? or [2, 3, 4].include? p.interaction_type }.collect(&:user_id)
       ids += moderation_user_ids_by_date[date].first.user_ids.split(',').map { |a| a.to_i } if moderation_user_ids_by_date[date]
       ids += question_user_ids_by_date[date].first.user_ids.split(',').map { |a| a.to_i } if question_user_ids_by_date[date]
       graph_data[date] = ids.uniq.count
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

  def self.graph_timely_publish domain = 30
    graph_data = Rails.cache.fetch "stat_timely_publish_#{domain}", :expires_in => 19.minutes do
      data = [["Date", "Good reply (<1 day)", "Ok reply (<3 days)", "Slow reply (>3)", "No reply"]]
      total_stat = []
      today_stat = 0
      questions = Question.ugc.where("questions.created_at > ?", domain.days.ago)
      good_replies = questions.not_pending.where("(questions.updated_at - questions.created_at < interval '1 day')")\
        .select(["to_char(questions.created_at, 'YYYY-MM-DD')"]).group("to_char(questions.created_at, 'YYYY-MM-DD')").count
      ok_replies = questions.not_pending.where("(questions.updated_at - questions.created_at > interval '1 day')")\
        .where("(questions.updated_at - questions.created_at < interval '3 days')")\
        .select(["to_char(questions.created_at, 'YYYY-MM-DD')"]).group("to_char(questions.created_at, 'YYYY-MM-DD')").count
      slow_replies = questions.not_pending.where("(questions.updated_at - questions.created_at > interval '3 days')")\
        .select(["to_char(questions.created_at, 'YYYY-MM-DD')"]).group("to_char(questions.created_at, 'YYYY-MM-DD')").count
      no_replies = questions.pending.select(["to_char(questions.created_at, 'YYYY-MM-DD')"]).group("to_char(questions.created_at, 'YYYY-MM-DD')").count

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
        today_stat = sprintf "%.1f%", good_normalized * 100 if date == Date.today
        total_stat << good_normalized if date > Date.today - 7.days
      end

      today_stat = good_replies.values.sum / (good_replies.values.sum  + ok_replies.values.sum + slow_replies.values.sum  + no_replies.values.sum ).to_f
      today_stat = sprintf "%.1f%", today_stat * 100
      total_stat = sprintf "%.1f%", (total_stat.sum / total_stat.size) * 100
      
      [data, {today: today_stat, total: total_stat}]
    end
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