class Publication < ActiveRecord::Base
	belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'
	belongs_to :publication_queue
	belongs_to :question
	has_many :conversations
	has_many :posts

  scope :published, -> { where("publications.published = ?", true) }

  def self.recently_published
    publications, posts = Rails.cache.fetch 'publications_recently_published', :expires_in => 10.minutes, :race_condition_ttl => 15 do
      publications = Publication.includes([:asker, :posts, :question => [:answers, :user]])\
        .published\
        .where("posts.interaction_type = 1", true)\
        .where("posts.created_at > ?", 1.days.ago)\
        .order("posts.created_at DESC")\
        .limit(15)\
        .includes(:question => :answers)\
        .all
      posts = Post.select([:id, :created_at, :publication_id])\
        .where("publication_id in (?)", publications.collect(&:id))\
        .order("created_at DESC")\
        .all
      [publications, posts]
    end
    return publications, posts
  end

  def self.recently_published_by_asker asker
    publications, posts = Rails.cache.fetch "publications_recently_published_by_asker_#{asker.id}", :expires_in => 5.minutes, :race_condition_ttl => 15 do
      publications = asker.publications\
        .published\
        .includes([:asker, :posts, :question => [:answers, :user]])\
        .where("posts.created_at > ? and posts.interaction_type = 1", 1.days.ago)\
        .order("posts.created_at DESC")\
        .all
      posts = Post.select([:id, :created_at, :publication_id])\
        .where("publication_id in (?)", publications.collect(&:id))\
        .order("created_at DESC")\
        .all
      [publications, posts]
    end
    return publications, posts
  end

  def self.recent_responses posts
    replies = Rails.cache.fetch 'publications_recent_responses', :expires_in => 10.minutes, :race_condition_ttl => 15 do
      replies = Post.answers\
        .select([:user_id, :interaction_type, :in_reply_to_post_id, :created_at])\
        .where("in_reply_to_post_id in (?)", posts.collect(&:id))\
        .order("created_at ASC")\
        .includes(:user)\
        .group_by(&:in_reply_to_post_id)
    end
    return replies
  end

  def self.recent_responses_by_asker asker, posts
    replies = Rails.cache.fetch "publications_recent_responses_by_asker_#{asker.id}", :expires_in => 5.minutes, :race_condition_ttl => 15 do
      replies = Post.select([:user_id, :interaction_type, :in_reply_to_post_id, :created_at])\
        .where(:in_reply_to_post_id => posts.collect(&:id))\
        .order("created_at ASC")\
        .includes(:user)\
        .group_by(&:in_reply_to_post_id)
    end
    return replies
  end

  def self.published_count
    Rails.cache.fetch('publications_published_count', :expires_in => 10.minutes) do
      Publication.where(:published => true).count
    end
  end
end
