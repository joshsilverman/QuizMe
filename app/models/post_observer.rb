class PostObserver < ActiveRecord::Observer
  def after_save(post)
    puts "after save!"
  end
end