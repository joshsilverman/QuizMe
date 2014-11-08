class RatingObserver < ActiveRecord::Observer
  def after_save(rating)
    rating.question.update_rating
  end
end