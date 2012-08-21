class AddPublishedToPublications < ActiveRecord::Migration
  def change
  	add_column :publications, :published, :boolean, :default => false
  end
end
