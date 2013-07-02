class Moderator < User
	has_many :moderations, foreign_key: :user_id

  scope :non_moderator, where('moderator_segment is null')
  scope :edger_mod, where(:moderator_segment => 1)
  scope :noob_mod, where(:moderator_segment => 2)
  scope :regular_mod, where(:moderator_segment => 3)
  scope :advanced_mod, where(:moderator_segment => 4)
  scope :super_mod, where(:moderator_segment => 5)	

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
		enough_mods = moderations.where('accepted is not null').count > 50
		enough_acceptance_rate = acceptance_rate > 0.9
		is_above_regular = lifecycle_above?(4)
		enough_mods and enough_acceptance_rate and is_above_regular
	end

	def is_advanced_mod?
		enough_mods = moderations.where('accepted is not null').count > 20
		enough_acceptance_rate = acceptance_rate > 0.8
		enough_mods and enough_acceptance_rate
	end

	def is_regular_mod?
		enough_mods = moderations.where('accepted is not null').count > 10
		enough_acceptance_rate = acceptance_rate > 0.65
		enough_mods and enough_acceptance_rate
	end

	def is_noob_mod?
		enough_mods = moderations.where('accepted is not null').count > 2
		enough_acceptance_rate = acceptance_rate > 0.5
		enough_mods and enough_acceptance_rate
	end

	def is_edger_mod?
		moderations.count > 0
	end


	def acceptance_rate
		accepted = moderations.where(accepted: true).count
		not_accepted = moderations.where(accepted: false).count
		total = accepted + not_accepted
		total == 0 ? 0 : (accepted.to_f / total.to_f)
	end
end