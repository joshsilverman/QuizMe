class Relationship < ActiveRecord::Base
  belongs_to :followed, :class_name => 'User', :foreign_key => :id
  belongs_to :follower, :class_name => 'User', :foreign_key => :id
end