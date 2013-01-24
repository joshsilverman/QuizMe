class Nudge < ActiveRecord::Base
  belongs_to :asker, :class_name => 'User', :foreign_key => :asker_id
  belongs_to :client, :class_name => 'User', :foreign_key => :client_id
  has_many :posts
  has_many :conversations, :through => :posts
  has_many :users, :through => :posts

  def send_to user
  	Post.dm(asker, user, text, {:long_url => "#{URL}/nudges/#{id}/#{user.id}", :link_type => 'wisr', :include_url => true})
  	# create post with url /posts/:id/nudge
  	# posts nudge route redirects to posts nudge url
  end
end