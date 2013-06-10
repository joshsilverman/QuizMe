class UserMailer < ActionMailer::Base
  default :from => "jsilverman@studyegg.com"
  
  def newsletter(user, jason, josh)
    @name = user.name || user.twi_name
    @weeks = (Date.today - Date.new(2012,8,20)).to_i/7
    @jason_text = jason
    @josh_text = josh

    mail(:to => "#{user.name} <#{user.email}>", :subject => "Wisr - Recent metrics & experiments")
  end

  def progress_report recipient, activity_summary, asker_hash
    @user = recipient
    @activity_summary = activity_summary
    @asker_hash = asker_hash
    @scripts = [
      "How can we make this service better?",
      "Any new topics that you'd like to learn about?",
      "What other information should we put into this progress report?",
      "Is this progress report helpful?"
    ]

    mail(:to => "#{@user.name} <#{@user.email}>", :subject => "Wisr - Progress Report")

    Mixpanel.track_event "progress report email sent", { :distinct_id => recipient.id }   
  end
end
