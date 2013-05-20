class UserMailer < ActionMailer::Base
  default :from => "jsilverman@studyegg.com"
  
  def newsletter(user, jason, josh)
    @name = user.name || user.twi_name
    @weeks = (Date.today - Date.new(2012,8,20)).to_i/7
    @jason_text = jason
    @josh_text = josh

    mail(:to => "#{user.name} <#{user.email}>", :subject => "Wisr - Recent metrics & experiments")
  end

  def progress_report user
  	
  end
end
