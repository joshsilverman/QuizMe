class AddFirstPostedAtToPublication < ActiveRecord::Migration
  def change
    add_column :publications, :first_posted_at, :timestamp
  end
end
