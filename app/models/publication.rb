class Publication < ActiveRecord::Base
	belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'
	belongs_to :publication_queue
	has_many :conversations
	has_many :posts
	# belongs_to :user, :foreign_key => 'asker_id'
	# belongs_to :topic
end
