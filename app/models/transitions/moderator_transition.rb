class ModeratorTransition < Transition

	def issue_badge
		badge = select_badge
		
		return unless Issuance.create(badge:badge, user:user).valid?
		last_active_asker.notify_badge_issued(user, badge)
	end

	private

	def select_badge
		Badge.find_by(to_segment: to_segment, segment_type: 5)
	end

	def last_active_asker
		moderator = user.becomes(Moderator)
		asker = moderator.moderations.order(created_at: :desc)
			.last.post.in_reply_to_user
		return unless asker.role == 'asker'

		asker.becomes(Asker)
	end
end
