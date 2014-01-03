class ModeratorTransition < Transition
	include Rails.application.routes.url_helpers

	def issue_badge
		badge = select_badge
		issuance = Issuance.create(badge:badge, user:user)

		return unless issuance.valid?
		options = {long_url: issuance_path(issuance)}
		last_active_asker.notify_badge_issued(user, badge, options)
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
