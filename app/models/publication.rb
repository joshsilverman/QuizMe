class Publication < ActiveRecord::Base
	belongs_to :asker, :class_name => 'User', :foreign_key => 'asker_id'
	belongs_to :publication_queue
	belongs_to :question
	has_many :conversations
	has_many :posts

  def self.recently_published
    publications = posts = []
    publications = Rails.cache.fetch 'publications_recently_published', :expires_in => 90.seconds do
      publications = Publication.includes(:asker, :posts)\
        .where("publications.published = ? and posts.interaction_type = 1", true)\
        .order("posts.created_at DESC").limit(15).includes(:question => :answers)
      posts = Rails.cache.fetch '_posts_recently_published', :expires_in => 90.seconds do
        Post.select([:id, :created_at, :publication_id])\
          .where(:provider => "twitter", :publication_id => publications.collect(&:id))\
          .order("created_at DESC") 
      end
      publications
    end

    return publications, posts
  end

  def self.published_count
    Rails.cache.fetch('publications_published_count', :expires_in => 10.minutes) do
      Publication.where(:published => true).count
    end
  end
end
