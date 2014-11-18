class Lesson < ActiveRecord::Base
	default_scope -> { where("type_id = 6") }
end