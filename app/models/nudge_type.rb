class NudgeType < ActiveRecord::Base
  belongs_to :client, :class_name => 'Client', :foreign_key => :client_id
  has_many :posts
  has_many :conversations, :through => :posts
  has_many :users, :through => :posts

  scope :active, where("active = ?", true)

  def send_to asker, user, dm = nil
    text.split("\n").each do |message|
      message.gsub!("{link}", Post.shorten_url("#{URL}/nudge/#{id}/#{user.id}/#{asker.id}", 'twi', 'wisr', asker.twi_screen_name)) if message.include? "{link}"
      dm = Post.dm(asker, user, message, {
    		:intention => 'nudge',
        :nudge_type_id => id
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
end