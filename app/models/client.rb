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

  def export_stats_to_csv
    Asker.export_stats_to_csv askers, 30
  end
end