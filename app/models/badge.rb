class Badge < ActiveRecord::Base
  has_many :questions, :through => :requirements
  has_many :users, :through => :issuances, :uniq => true
  has_many :requirements
  has_many :issuances
  belongs_to :asker, :class_name => 'User'

  def filename_nocolor
    filename.gsub ".", "-nocolor."
  end

  def img_path
    "/assets/badges/#{asker.twi_screen_name.downcase}/#{filename}"
  end

  def img_path_nocolor
    "/assets/badges/#{asker.twi_screen_name.downcase}/#{filename_nocolor}"
  end
end
