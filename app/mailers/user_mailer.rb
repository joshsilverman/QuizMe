class UserMailer < ActionMailer::Base
  default :css => 'application', :from => "Wisr <app6915090@heroku.com>"

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
