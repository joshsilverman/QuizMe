class Tag < ActiveRecord::Base
  has_and_belongs_to_many :posts, :uniq => true
  has_and_belongs_to_many :users, :uniq => true
end
