class PostQueue < ActiveRecord::Base
	
	def self.enqueue_questions(current_acct, question_array)
    question_array.each_with_index do |q,i|
      parent = Post.create(
        :question_id => q.id,
        :provider => 'parent',
        :text => q.text,
        :url => nil,
        :link_type => nil,
        :post_type => 'parent',
        :provider_post_id => nil,
        :to_twi_user_id => nil,
        :asker_id => current_acct.id,
        :parent_id => nil)
      PostQueue.create(:asker_id => current_acct.id,
                       :post_id => parent.id,
                       :index => i)
    end
  end

  def self.clear_queue(current_acct=nil)
  	if current_acct
  		items = PostQueue.where(:asker_id => current_acct.id)
  		items.destroy_all
  	else
  		PostQueue.destroy_all
  	end
  end
end
