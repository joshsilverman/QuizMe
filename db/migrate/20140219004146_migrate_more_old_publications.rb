class MigrateMoreOldPublications < ActiveRecord::Migration
  def up

    count = 25000

    publications = Publication.published
      .where("_answers IS NULL or _asker IS NULL")
      .order(created_at: :desc).limit(count)

    publications.each do |p| 
      p.update_question
    end


    publications = Publication.published
      .where("first_posted_at IS NULL")
      .order(created_at: :desc).limit(count)

    publications.each do |publication|
      first_post = publication.posts.sample

      next unless first_post

      first_posted_at = first_post.created_at

      publication.update first_posted_at: first_posted_at
    end

  end
end
