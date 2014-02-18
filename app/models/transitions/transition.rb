class Transition < ActiveRecord::Base
  belongs_to :user

  scope :to_superuser, -> { where("segment_type = 1 and to_segment = 6") }
  scope :to_pro, -> { where("segment_type = 1 and to_segment = 5") }
  scope :to_advanced, -> { where("segment_type = 1 and to_segment = 4") }
  scope :to_regular, -> { where("segment_type = 1 and to_segment = 3") }
  scope :to_noob, -> { where("segment_type = 1 and to_segment = 2") }
  scope :to_edger, -> { where("segment_type = 1 and to_segment = 1") }
  scope :to_interested, -> { where("segment_type = 1 and to_segment = 7") }

  scope :lifecycle, -> { where("segment_type = 1") }
  scope :moderator, -> { where("segment_type = 5") }

  def is_positive?
    return true if SEGMENT_HIERARCHY[segment_type].index(from_segment).nil? or SEGMENT_HIERARCHY[segment_type].index(to_segment) > SEGMENT_HIERARCHY[segment_type].index(from_segment)
    false
  end

  def is_above? above_segment
    return true if SEGMENT_HIERARCHY[segment_type].index(to_segment) > SEGMENT_HIERARCHY[segment_type].index(above_segment)
    false
  end

  def segment
    case self.segment_type
    when 1
      return 'lifecycle'
    when 2
      return 'activity'
    when 3
      return 'interaction'
    when 4
      return 'author'
    end
  end

  def issue_badge
    case segment_type
    when 1
      self.becomes(LifecycleTransition).issue_badge
    when 5
      self.becomes(ModeratorTransition).issue_badge
    end
  end
end
