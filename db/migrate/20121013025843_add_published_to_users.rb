class AddPublishedToUsers < ActiveRecord::Migration
  def change
    add_column :users, :published, :boolean

    User.askers.each{|a| a.update_attribute :published, true}
  end
end
