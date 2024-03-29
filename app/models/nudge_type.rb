class NudgeType < ActiveRecord::Base
  belongs_to :client, :class_name => 'Client', :foreign_key => :client_id
  has_many :posts
  has_many :conversations, :through => :posts
  has_many :users, :through => :posts

  scope :active, -> { where("active = ?", true) }
  scope :automatic, -> { where("automatic = ?", true) }

  def send_to asker, user, dm = nil, short_url = nil
    text.split("\n").each do |message|
      
      if message.include? "{link}"
        short_url = Post.format_url("#{URL}/nudge/#{id}/#{user.id}/#{asker.id}", 'twi', 'wisr', asker.twi_screen_name, user.twi_screen_name)
        message.gsub!("{link}", short_url)
      end

      dm = asker.send_private_message(user, message, {
    		:intention => 'nudge',
        :nudge_type_id => id,
        :short_url => short_url
    	})
    end
    if dm
      MP.track_event "nudge sent", {
        :distinct_id => user.id,
        :asker => asker.twi_screen_name,
        :client => client.twi_screen_name,
        :lifecycle_segment => user.lifecycle_segment,
        :nudge_type_id => id
      }
    end

    dm
  end

  def register_conversion user, asker, is_repeat_conversion = false
    nudges_received = user.nudges_received(id)
    if nudges_received.present? 
      if nudges_received.select { |n| n.converted }.blank? # no converted nudges, first time conversion
        nudges_received.each { |nudge| nudge.update_attribute :converted, true }
      else # already has converted nudges, repeat conversion
        is_repeat_conversion = true
      end

      MP.track_event "nudge conversion", {
        :distinct_id => user.id,
        :asker => asker.twi_screen_name,
        :client => client.twi_screen_name,
        :lifecycle_segment => user.lifecycle_segment,
        :nudge_type_id => id,
        :is_repeat => is_repeat_conversion
      }        
    end
  end
end