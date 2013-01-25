class NudgeType < ActiveRecord::Base
  belongs_to :client, :class_name => 'Client', :foreign_key => :client_id
  has_many :posts
  has_many :conversations, :through => :posts
  has_many :users, :through => :posts

  scope :active, where("active = ?", true)

  def send_to asker, user
  	dm = Post.dm(asker, user, text, {
  		:long_url => "#{URL}/nudge/#{id}/#{user.id}/#{asker.id}", 
  		:link_type => 'wisr', 
  		:include_url => true,
  		:intention => 'nudge',
      :nudge_type_id => id
  	})
    if dm
      Mixpanel.track_event "nudge sent", {
        :distinct_id => user.id,
        :asker => asker.twi_screen_name,
        :client => client.twi_screen_name
      }        
    end
  end
end