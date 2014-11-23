class Lesson < Topic
	default_scope -> { where("type_id = 6") }
end