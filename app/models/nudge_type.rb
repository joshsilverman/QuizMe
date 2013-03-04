class NudgeType < ActiveRecord::Base
  belongs_to :client, :class_name => 'Client', :foreign_key => :client_id
  has_many :posts
  has_many :conversations, :through => :posts
  has_many :users, :through => :posts

  scope :active, where("active = ?", true)
  scope :automatic, where("automatic = ?", true)

  def send_to asker, user, dm = nil, short_url = nil
    text.split("\n").each do |message|
      
      if message.include? "{link}"
        short_url = Post.shorten_url("#{URL}/nudge/#{id}/#{user.id}/#{asker.id}", 'twi', 'wisr', asker.twi_screen_name)
        message.gsub!("{link}", short_url)
      end

      dm = Post.dm(asker, user, message, {
    		:intention => 'nudge',
        :nudge_type_id => id,
        :short_url => short_url
    	})
    end
    if dm
      Mixpanel.track_event "nudge sent", {
        :distinct_id => user.id,
        :asker => asker.twi_screen_name,
        :client => client.twi_screen_name,
        :lifecycle_segment => user.lifecycle_segment
      }        
    end
  end

  def register_conversion user, asker
    nudges_received = user.nudges_received(id)
    if nudges_received.present? and nudges_received.select { |n| n.converted }.blank?
      Mixpanel.track_event "nudge conversion", {
        :distinct_id => user.id,
        :asker => asker.twi_screen_name,
        :client => client.twi_screen_name,
        :lifecycle_segment => user.lifecycle_segment,
        :nudge_type_id => id
      }  
      nudges_received.each { |nudge| nudge.update_attribute :converted, true }
      
      Post.trigger_split_test(user.id, "SATHabit copy (click-through) < 123 >") if client.id == 14699
    end
  end
end