class Authorization < ActiveRecord::Base
	belongs_to :user
  # attr_accessible :email, :name, :provider, :uid
end
