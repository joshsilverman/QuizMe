class CreateModerationBadges < ActiveRecord::Migration
  def up
    badge_details = [
      {
        segment_type: 5,
        to_segment: 1,
        title: 'Newborn Moderator',
        description: 'Welcome to the club! You\'re now a moderator in the Wisr community. This is the kind of effort that keeps our community going.',
        filename: 'badges/moderators/mod-badges_01.png'
        },
      {
        segment_type: 5,
        to_segment: 2,
        title: 'Twirly Cap',
        description: 'Have a twirly cap -- you\'re starting to soar! With your help we\'ve responded to a few more learners.',
        filename: 'badges/moderators/mod-badges_02.png'
        },
      {
        segment_type: 5,
        to_segment: 3,
        title: 'Graduation Day',
        description: "It's Graduation Day! You've been promoted as a moderator and will now have a greater effect with your grades.",
        filename: 'badges/moderators/mod-badges_03.png'
        },
      {
        segment_type: 5,
        to_segment: 4,
        title: 'First Lecture',
        description: "You're now ready to get in front of the class and lecture! You're grades are now weighted very high and will often be enough to issue a final grade to a learner.",
        filename: 'badges/moderators/mod-badges_04.png'
        },
      {
        segment_type: 5,
        to_segment: 5,
        title: 'Badass Teacher',
        description: "Badass, need I say more?! You can now issue grades all on your own. Just remember: with great power comes great responsibility!",
        filename: 'badges/moderators/mod-badges_05.png'
        }
    ]

    badge_details.each do |badge_detail|
      badge = Badge.find_or_initialize_by(to_segment: badge_detail[:to_segment], segment_type: badge_detail[:segment_type])
      badge.update badge_detail
    end
  end

  def down
    Badge.where(segment_type: 5).destroy_all
  end
end
