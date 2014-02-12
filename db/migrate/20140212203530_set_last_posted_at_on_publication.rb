class SetLastPostedAtOnPublication < ActiveRecord::Migration
  def up
    publications = Publication.published.where('created_at > ?', 7.days.ago)

    publications.each do |publication|
      first_posted_at = publication.posts.sample.created_at

      next if publication.first_posted_at

      publication.update first_posted_at: first_posted_at
    end
  end
end
