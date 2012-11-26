task :segment => :environment do

  def init
    @segments = {
      :active => {
        :superusers => [],
        :advancedusers => [],
        :nubes => [],
        :edgers => [],
        :unknown => []
      },
      :disengaging => {
        :superusers => [],
        :advancedusers => [],
        :nubes => [],
        :edgers => [],
        :unknown => []
      },
      :disengaged => {
        :superusers => [],
        :advancedusers => [],
        :nubes => [],
        :edgers => [],
        :unknown => []
      }
    }
  end

  #classify into superuser, active, new, disengaged, spam, unknown
  def segment_users
    users = User.includes(:posts).where("posts.autospam != ? or posts.text IS NULL", true)
    @now = Post.order("created_at DESC").first.created_at

    users.each do |user|
      segment_user user
    end

    # output
    puts "\n        users:\n"
    @segments.each do |recency, users_by_level|

      puts "          #{recency}:\n"
      users_by_level.each do |level, users|

        puts "            #{level} (#{users.count}) (#{users.map{|u| u.id}}):\n"
        users.each do |user|
          next unless user.posts.count > 0
          puts "              #{user.twi_screen_name} (#{user.posts.group_by{|p| p.in_reply_to_user_id}.values.sort{|g1,g2| g1.count <=> g2.count}.last.first.in_reply_to_user_id})\n"
        end
      end
    end

  end

  def segment_user user
    if is_superuser? user
      level = :superusers
    elsif is_advanceduser? user
      level = :advancedusers
    elsif is_nube? user
      level = :nubes
    elsif is_edger? user
      level = :edgers
    else
      level = :unknown
    end

    if is_active? user
      recency = :active
    elsif is_disengaging? user
      recency = :disengaging
    else
      recency = :disengaged
    end

    @segments[recency][level] << user
    
  end

  def is_active? user
    user.posts.each do |post|
      return true if post.created_at > @now - 3.days
    end
    false
  end

  def is_disengaging? user
    user.posts.each do |post|
      return true if post.created_at > @now - 2.weeks
    end
    false
  end

  def is_superuser? user
    enough_posts = true if user.posts.count >= 10
    enough_frequency = true if posts_by_week(user.posts).length >= 3

    enough_posts and enough_frequency
  end

  def is_advanceduser? user
    enough_posts = true if user.posts.count >= 3 and user.posts.count < 10
    enough_frequency = true if posts_by_day(user.posts).length >= 3

    enough_posts and enough_frequency
  end

  def is_nube? user
    true if user.posts.count > 1 and user.posts.count < 3
  end

  def is_edger? user
    true if user.posts.count == 1
  end

  def posts_by_week posts
    posts.group_by {|p| p.created_at.strftime('%W')}
  end

  def posts_by_day posts
    posts.group_by {|p| p.created_at.strftime('%D')}
  end

  init
  segment_users
end