class Client < User
  belongs_to :rate_sheet
  has_many :askers
  has_many :nudges, :foreign_key => :client_id

  default_scope where(:role => 'client')

  def self.includes_rate_sheets_by_created_at
    Rails.cache.fetch('clients_includes_rate_sheets_by_created_at', :expires_in => 5.minutes) do
      Client.includes(:rate_sheet).order("created_at ASC").all
    end
  end

  # def self.nudge user, asker, user_post = nil

  #   if asker.client and asker.client.id == 14699 #sathabit
  #     puts 'For sathabit'
  #     sathabit = asker.client
  #     askers = sathabit.askers
  #   elsif asker.client and asker.client.id == 23624 #science_client
  #     puts 'For science_client'
  #     science_client = asker.client
  #     askers = science_client.askers
  #   else
  #     puts 'Not client handle'
  #     return false
  #   end

  #   correct_count = user.posts.not_spam\
  #     .where("in_reply_to_user_id IN (?)", askers.collect(&:id))\
  #     .where('correct = ?', true).count

  #   if user.client_nudge # verified
  #     puts 'Already nudged'
  #     return false
  #   elsif user_post and user_post.correct == false
  #     puts 'Last answer wrong'
  #     return false
  #   elsif user_post and user_post.correct == nil and user_post.autocorrect == nil and 
  #     puts 'The current post was not graded'
  #     return false
  #   elsif correct_count < 3
  #     puts 'Not enough correct answers'
  #     return false
  #   end

  #   puts "Correct for client: " + correct_count.to_s
  #   puts "Current post correctness: " + user_post.correct.to_s if user_post

  #   user.client_nudge = true
  #   Client.nudge_sathabit user, asker if sathabit
  #   Client.nudge_instaedu user, asker if science_client
  #   user.save
  # end

  # def self.nudge_sathabit user, asker
  #   message = "You're doing really well! I offer a much more comprehensive (free) course here:"
  #   puts "From SAThabit: " + message
  #   long_url = "http://www.testive.com/sathabit/?version=email&utm_source=wisr&utm_twi_screen_name=#{user.twi_screen_name}"
  #   dm_status = Post.dm(asker, user, message, {:long_url => long_url, :link_type => 'wisr', :include_url => true})
  # end

  # def self.nudge_instaedu user, asker
  #   message = "If you're interested, we work with a Biology tutor website. Could this be helpful? "
  #   puts "From instaEDU: " + message
  #   long_url = "http://instaedu.com/Biology-online-tutoring/?utm_source=wisr"
  #   dm_status = Post.dm(asker, user, message, {:long_url => long_url, :link_type => 'wisr', :include_url => true})
  #   message = "Are you currently a student? Could this be helpful?"
  #   dm_status = Post.dm(asker, user, message, {:long_url => nil, :link_type => 'wisr', :include_url => true})
  # end

  def export_stats_to_csv
    Asker.export_stats_to_csv askers, 30
  end
end