class Conversation < ActiveRecord::Base
	belongs_to :post
	has_many :posts
	belongs_to :publication
	# belongs_to :user, :foreign_key => 'asker_id'
	# belongs_to :topic
end
