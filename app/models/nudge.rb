class Nudge < ActiveRecord::Base
  # attr_accessible :title, :body
  belongs_to :asker, :class_name => 'User', :foreign_key => :asker_id
  belongs_to :client, :class_name => 'User', :foreign_key => :client_id
  has_many :posts
  has_many :conversations, :through => :posts
  has_many :users, :through => :posts

end
