class Publication < ActiveRecord::Base
	belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'
	belongs_to :publication_queue
	belongs_to :question
	has_many :conversations
	has_many :posts

  scope :published, -> { where("publications.published = ?", true) }

  def self.recent
    Rails.cache.fetch 'publications_recent' do
      Publication.includes([:asker, :posts, :question => [:answers, :user]])\
        .published\
        .where("posts.interaction_type = 1", true)\
        .where("posts.created_at > ?", 1.days.ago)\
        .order("posts.created_at DESC")\
        .limit(15)\
        .includes(:question => :answers)\
        .to_a
    end
  end

  def self.recent_by_asker asker
    Rails.cache.fetch "publications_recent_by_asker_#{asker.id}" do
      asker.publications\
        .published\
        .includes([:asker, :posts, :question => [:answers, :user]])\
        .where("posts.created_at > ? and posts.interaction_type = 1", 1.days.ago)\
        .order("posts.created_at DESC")\
        .to_a
    end
  end

  def self.recent_by_asker_and_id asker_id, id
    Rails.cache.fetch "publication_recent_by_asker_and_id#{asker_id}-#{id}" do
      Publication.published.where(id: id, asker_id: asker_id)\
        .includes([:asker, :posts, :question => [:answers, :user]]).first
    end
  end

  def self.recent_publication_posts publications
    Rails.cache.fetch 'publications_posts_recent', :expires_in => 5.minutes do
      Post.select([:id, :created_at, :publication_id])\
        .where("publication_id in (?)", publications.collect(&:id))\
        .order("created_at DESC")\
        .to_a
    end
  end

  def self.recent_publication_posts_by_asker asker, publications
    Rails.cache.fetch "publications_posts_recent_#{asker.id}", :expires_in => 5.minutes do
      Post.select([:id, :created_at, :publication_id])\
        .where("publication_id in (?)", publications.collect(&:id))\
        .order("created_at DESC")\
        .to_a
    end
  end  

  def self.recent_responses posts
    Rails.cache.fetch 'publications_recent_responses', :expires_in => 5.minutes do
      Post.answers\
        .select([:user_id, :interaction_type, :in_reply_to_post_id, :created_at])\
        .where("in_reply_to_post_id in (?)", posts.collect(&:id))\
        .order("created_at ASC")\
        .includes(:user)\
        .group_by(&:in_reply_to_post_id)
    end
  end

  def self.recent_responses_by_asker asker, posts
    Rails.cache.fetch "publications_recent_responses_by_asker_#{asker.id}", :expires_in => 5.minutes do
      Post.select([:user_id, :interaction_type, :in_reply_to_post_id, :created_at])\
        .where(:in_reply_to_post_id => posts.collect(&:id))\
        .order("created_at ASC")\
        .includes(:user)\
        .group_by(&:in_reply_to_post_id)
    end
  end

  def self.published_count
    Rails.cache.fetch('publications_published_count', :expires_in => 10.minutes) do
      Publication.where(:published => true).count
    end
  end
end
