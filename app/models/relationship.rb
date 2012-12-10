class Relationship < ActiveRecord::Base
  belongs_to :follower, class_name: 'User', :foreign_key => :id
  belongs_to :follow, class_name: 'Asker', :foreign_key => :id
end