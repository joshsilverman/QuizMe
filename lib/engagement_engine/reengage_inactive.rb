module EngagementEngine::ReengageInactive

  def self.included base
    base.extend ClassMethods
  end

  module ClassMethods
    def max_hourly_reengagements
      90
    end

    def reengage_inactive_users options = {}
      strategy = options[:strategy]
      strategy_string = options[:strategy].join "/" if strategy

      user_ids_to_last_active_at = User.get_ids_to_last_active_at

      user_ids_to_last_reengaged_at = Hash[*Post.not_spam\
        .reengage_inactive\
        .where('posts.in_reply_to_user_id in (?)', user_ids_to_last_active_at.keys)\
        .select(["in_reply_to_user_id", "max(created_at) as last_reengaged_at"])\
        .group("in_reply_to_user_id").map{|p| [p.in_reply_to_user_id, p.last_reengaged_at]}.flatten]

      @question_sent_by_asker_counts = {}
      reengagements_sent = 0
      user_ids_to_last_active_at.each do |user_id, last_active_at|
        break if reengagements_sent >= max_hourly_reengagements

        unless options[:strategy]
          strategy_string = "1/2/4/8/16/30/60"
          strategy = strategy_string.split("/").map { |e| e.to_i }
        end

        last_reengaged_at = user_ids_to_last_reengaged_at[user_id] || 1000.years.ago

        aggregate_intervals = 0
        ideal_last_reengage_at = nil
        strategy.each do |interval|
          if (last_active_at + (aggregate_intervals + interval).days) < Time.now
            aggregate_intervals += interval
            ideal_last_reengage_at = last_active_at + aggregate_intervals.days
          else
            break
          end
        end

        if (ideal_last_reengage_at and (last_reengaged_at < ideal_last_reengage_at))
          if Asker.reengage_user(user_id, {strategy: strategy_string, interval: aggregate_intervals, last_active_at: last_active_at, type: options[:type]})
            reengagements_sent += 1
          end
        end
      end
    end

    def reengage_user user_id, options = {}
      user = User.where(id: user_id).first
      return false if user.nil?
      return false if !user.contactable?
      return false unless (Asker.published_ids && user.asker_follows.collect(&:id)).present? # make sure there are published askers to reengage from

      asker, question, publication, text, long_url = nil, nil, nil, nil, nil
      reengagement_type = options[:type] || user.pick_reengagement_type(options[:last_active_at])
      case reengagement_type
      when :question
        return false unless asker = user.select_reengagement_asker
        return false unless question = asker.select_question(user)
        text = question.text
        publication = question.publications.published.order("created_at DESC").first
        intention = 'reengage inactive'
      when :moderation
        asker = user.asker_follows.sample
        text = I18n.t("reengagements.moderation").sample
        text.gsub! '<link>', asker.authenticated_link("#{URL}/moderations/manage", user, (Time.now + 1.week))
        intention = 'request mod'
      when :author
        # @deprecated on 09/04/2014 remove after error stops being raised
        raise "call to deprecated 'solicit ugc'"
      end

      if reengagement_type == :question
        if asker and publication
          long_url = "#{URL}/#{asker.subject_url}/#{publication.id}"
        else
          long_url = "#{URL}/questions/#{question.id}"
        end
      end

      return false unless asker and text

      @question_sent_by_asker_counts[asker.id] ||= 0
      return false unless @question_sent_by_asker_counts[asker.id] < 25 # limit number of reengagements sent to 25 per session
      @question_sent_by_asker_counts[asker.id] += 1

      if reengagement_type == :question
        send_message(user, asker, text, {
          reply_to: user.twi_screen_name,
          long_url: long_url ? long_url : nil,
          in_reply_to_user_id: user.id,
          posted_via_app: true,
          requires_action: false,
          link_to_parent: false,
          link_type: "reengage",
          intention: intention,
          include_answers: true,
          include_url: true,
          publication_id: (publication ? publication.id : nil),
          question_id: (question ? question.id : nil),
          is_reengagement: true
        })
      else
        asker.send_private_message(user, text, {
          posted_via_app: true,
          long_url: long_url ? long_url : nil,
          requires_action: false,
          interaction_type: 4,
          link_type: "reengage",
          intention: intention,
          include_answers: true,
          is_reengagement: true
        })
      end

      MP.track_event "reengage inactive", {
        distinct_id: user.id,
        interval: options[:interval],
        strategy: options[:strategy],
        asker: asker.twi_screen_name,
        type: reengagement_type
      }

      sleep(1) if !Rails.env.test?

      return true
    end

    private

    def send_message user, asker, text, options

      if user.lifecycle_above? 1
        options[:interaction_type] = 2
        asker.send_public_message(text, options)
      else
        options[:interaction_type] = 4
        asker.send_private_message(user, text, options)
      end
    end
  end
end
