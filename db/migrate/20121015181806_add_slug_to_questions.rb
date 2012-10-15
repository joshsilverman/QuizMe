class AddSlugToQuestions < ActiveRecord::Migration
  def change
  	add_column :questions, :slug, :string
  	
  	Question.all.each do |question|
  		question.update_attribute(:slug, question.slug_text)
  	end
  end
end
