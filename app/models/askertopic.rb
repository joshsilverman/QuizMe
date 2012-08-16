class Askertopic < ActiveRecord::Base
	belongs_to :user, :foreign_key => 'asker_id'
	belongs_to :topic
end
