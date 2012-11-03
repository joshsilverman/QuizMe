class Badge < ActiveRecord::Base
  has_many :questions, :through => :requirements
  has_many :users, :through => :issuances
  has_many :requirements
  has_many :issuances

  def filename_nocolor
    filename.gsub ".", "-nocolor."
  end
end
