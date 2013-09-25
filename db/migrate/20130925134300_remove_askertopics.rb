class RemoveAskertopics < ActiveRecord::Migration
  def change
  	drop_table :askertopics
  end
end
