class RatingObserver < ActiveRecord::Observer
  def after_save(rating)
    rating.question.update_rating
    rating.question.send_rating_to_publication
  end
end