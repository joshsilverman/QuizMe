class Asker < User
  belongs_to :client
  has_many :questions, :foreign_key => :created_for_asker_id

  default_scope where(:role => 'asker')

  def unresponded_count
    posts = Post.includes(:conversation).where("posts.requires_action = ? and posts.in_reply_to_user_id = ? and (posts.spam is null or posts.spam = ?) and posts.user_id not in (?)", true, id, false, Asker.all.collect(&:id))
    count = posts.not_spam.where("interaction_type = 2").count
    count += posts.not_spam.where("interaction_type = 4").count :user_id, :distinct => true

    count
  end
end