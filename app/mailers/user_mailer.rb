class UserMailer < ActionMailer::Base
  default :from => "Wisr <app6915090@heroku.com>"
  
  def newsletter(user, jason, josh)

    ActionMailer::Base.smtp_settings = {
      :address              => "smtp.gmail.com",
      :port                 => 587,
      :domain               => "studyegg.com",
      :user_name            => "jsilverman@studyegg.com",
      :password             => "GlJnb@n@n@",
      :authentication       => "plain",
      :enable_starttls_auto => true
    }

    @name = user.name || user.twi_name
    @weeks = (Date.today - Date.new(2012,8,20)).to_i/7
    @jason_text = jason
    @josh_text = josh

    mail(:to => "#{user.name} <#{user.email}>", :from => "jsilverman@studyegg.com", :subject => "Wisr - Recent metrics & experiments")
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
  end
end
