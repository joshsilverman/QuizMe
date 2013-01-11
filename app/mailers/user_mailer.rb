class UserMailer < ActionMailer::Base
  default :from => "jsilverman@studyegg.com"
  
  def newsletter(user = nil)
    @user = User.find 11
    mail(:to => "#{@user.name} <#{@user.email}>", :subject => "Newsletter")
  end
end
