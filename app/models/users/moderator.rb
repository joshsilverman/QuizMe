class Moderator < User
	has_many :moderations, foreign_key: :user_id
	has_many :post_moderations, foreign_key: :user_id, class_name: 'PostModeration'
	has_many :question_moderations, foreign_key: :user_id, class_name: 'QuestionModeration'

  scope :non_moderator, -> { where('moderator_segment is null') }
  scope :edger_mod, -> { where(:moderator_segment => 1) }
  scope :noob_mod, -> { where(:moderator_segment => 2) }
  scope :regular_mod, -> { where(:moderator_segment => 3) }
  scope :advanced_mod, -> { where(:moderator_segment => 4) }
  scope :super_mod, -> { where(:moderator_segment => 5) }

  def moderator_segment_above? segment_id
		return false if moderator_segment.nil?
		return false if SEGMENT_HIERARCHY[5].index(segment_id).blank?
		return true if segment_id.nil?
		return true if SEGMENT_HIERARCHY[5].index(moderator_segment) > SEGMENT_HIERARCHY[5].index(segment_id)
		false  	
  end

	# moderator segment checks
	def update_moderator_segment
		if is_super_mod?
			level = 5
		elsif is_advanced_mod?
			level = 4
		elsif is_regular_mod?
			level = 3
		elsif is_noob_mod?
			level = 2
		elsif is_edger_mod?
			level = 1
		else
			level = nil
		end

		transition :moderator, level
	end

	def is_super_mod?

		_50_mods = post_moderations.where('accepted is not null').count > 50
		_90_acceptance_rate = post_moderation_acceptance_rate > 0.9
		enough_mods_and_acceptance_rate = (_50_mods and _90_acceptance_rate)

		_100_mods = post_moderations.where('accepted is not null').count > 100
		_875_acceptance_rate = post_moderation_acceptance_rate > 0.875
		enough_mods_and_acceptance_rate ||= (_100_mods and _875_acceptance_rate)

		_200_mods = post_moderations.where('accepted is not null').count > 200
		_85_acceptance_rate = post_moderation_acceptance_rate > 0.85
		enough_mods_and_acceptance_rate ||= (_200_mods and _85_acceptance_rate)

		is_above_regular = lifecycle_above?(4)
		enough_mods_and_acceptance_rate and is_above_regular
	end

	def is_advanced_mod?
		enough_mods = post_moderations.where('accepted is not null').count > 20
		enough_acceptance_rate = post_moderation_acceptance_rate > 0.8
		enough_mods and enough_acceptance_rate
	end

	def is_regular_mod?
		enough_mods = post_moderations.where('accepted is not null').count > 10
		enough_acceptance_rate = post_moderation_acceptance_rate > 0.65
		enough_mods and enough_acceptance_rate
	end

	def is_noob_mod?
		enough_mods = post_moderations.where('accepted is not null').count > 2
		enough_acceptance_rate = post_moderation_acceptance_rate > 0.5
		enough_mods and enough_acceptance_rate
	end

	def is_edger_mod?
		post_moderations.count > 0
	end

	def is_question_super_mod?
		return true if (ADMINS.include?(id))
		enough_acceptance_rate = question_moderation_acceptance_rate > 0.9 
		enough_mods = question_moderations.where('accepted is not null').count > 29
		return true if enough_acceptance_rate and enough_mods
		return false
	end

	def post_moderation_acceptance_rate
		accepted = post_moderations.where(accepted: true).count
		not_accepted = post_moderations.where(accepted: false).count
		total = accepted + not_accepted
		total == 0 ? 0 : (accepted.to_f / total.to_f)
	end

	def question_moderation_acceptance_rate
		accepted = question_moderations.where(accepted: true).count
		not_accepted = question_moderations.where(accepted: false).count
		total = accepted + not_accepted
		total == 0 ? 0 : (accepted.to_f / total.to_f)		
	end
end