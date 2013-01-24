class Nudge < ActiveRecord::Base
  belongs_to :client, :class_name => 'User', :foreign_key => :client_id
  has_many :posts
  has_many :conversations, :through => :posts
  has_many :users, :through => :posts

  def send_to user
  	Post.dm(asker, user, text, {
  		:long_url => "#{URL}/nudge/#{id}/#{user.id}", 
  		:link_type => 'wisr', 
  		:include_url => true,
  		:intention => 'nudge'
  	})
  end
end