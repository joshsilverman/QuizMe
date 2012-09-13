class AddResourceUrlToQuestions < ActiveRecord::Migration
  def change
    add_column :questions, :resource_url, :text
  end
end
