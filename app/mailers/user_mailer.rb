class UserMailer < ActionMailer::Base
  default :from => "jsilverman@studyegg.com"
  
  def newsletter(user, jason, josh)
    @name = user.name || user.twi_name
    @weeks = (Date.today - Date.new(2012,8,20)).to_i/7
    @jason_text = jason
    @josh_text = josh

    mail(:to => "#{user.name} <#{user.email}>", :subject => "Wisr - Recent metrics & experiments")
  end

  def progress_report recipient
    @user = recipient
    @activity_summary = @user.activity_summary(since: 1.week.ago, include_ugc: true, include_progress: true)
    @asker_hash = Asker.published.group_by(&:id)
    
    mail(:to => "#{@user.name} <#{@user.email}>", :subject => "Wisr - Progress Report")
  end
end
