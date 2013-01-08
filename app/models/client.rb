class Client < User
  belongs_to :rate_sheet
  has_many :askers

  default_scope where(:role => 'client')

  def self.includes_rate_sheets_by_created_at
    Rails.cache.fetch('clients_includes_rate_sheets_by_created_at', :expires_in => 5.minutes) do
      Client.includes(:rate_sheet).order("created_at ASC").all
    end
  end

  def self.nudge user, asker, user_post

    @client = Client.find 14699
    correct_count = user.posts.not_spam\
      .where("in_reply_to_user_id IN (?)", @client.askers.collect(&:id))\
      .where('correct = ?', true).count

    if asker.client != @client # vefified
      puts 'Not for SAThabit'
      return false
    elsif user.client_nudge # verified
      puts 'Already nudged'
      return false
    elsif user_post.correct == false
      puts 'Last answer wrong'
      return false
    elsif correct_count < 3
      puts 'not enough correct answers'
      return false
    end

    user.client_nudge = true
    message = "You're doing really well! I offer a much more comprehensive (free) course here:"
    long_url = "http://www.testive.com/sathabit/?version=email&utm_source=wisr&utm_twi_screen_name=#{user.twi_screen_name}"
    dm_status = Post.dm(asker, user, message, {:long_url => long_url, :link_type => 'wisr', :include_url => true})
    user.save
  end

  def export_stats_to_csv domain = 30

    _user_ids_by_day = Post.not_us.not_spam\
      .where("in_reply_to_user_id IN (?)", askers.collect(&:id))\
      .where("created_at > ?", Date.today - (domain + 31).days)\
      .select(["to_char(posts.created_at, 'YY/MM/DD') as created_at", "array_to_string(array_agg(user_id),',') AS user_ids"]).group("to_char(posts.created_at, 'YY/MM/DD')").all\
      .map{|p| {:created_at => p.created_at, :user_ids => p.user_ids.split(",")}}
    user_ids_by_day = _user_ids_by_day  
      .group_by{|p| p[:created_at]}\
      .each{|k,r| r.replace r.first[:user_ids].uniq }\

    _user_ids_by_week = _user_ids_by_day.group_by{|p| p[:created_at].beginning_of_week}
    user_ids_by_week = {}
    _user_ids_by_week.each{|date, ids_wrapped_in_posts| user_ids_by_week[date] = ids_wrapped_in_posts.map{|ids_wrapped_in_post|ids_wrapped_in_post[:user_ids]}.flatten.uniq}
    user_ids_by_week

    data = []
    user_ids_by_week.each do |date, user_ids|
      row = [date]
      row += [user_ids_by_day.reject{|ddate, user_ids| ddate > date + 6.days}.values.flatten.uniq.count]
      row += [user_ids_by_day.reject{|ddate, user_ids| ddate > date + 6.days || ddate < date - 24.days}.values.flatten.uniq.count]
      row += [user_ids.count]
      row += [(user_ids_by_day.reject{|ddate, user_ids| ddate > date + 6.days || ddate < date }.values.flatten.count.to_f / 7.0).round]
      data << row
    end
    data = [['Date', 'AUs', 'MAUs', 'WAUs', 'DAUs']] + data
    require 'csv'
    CSV.open("tmp/client.csv", "wb") do |csv|
      data.transpose.each do |row|
        csv << row
      end
    end
  end
end