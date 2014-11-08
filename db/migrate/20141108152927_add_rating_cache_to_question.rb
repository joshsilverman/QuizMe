class AddRatingCacheToQuestion < ActiveRecord::Migration
  def change
    add_column :questions, :_rating, :hstore
  end
end
