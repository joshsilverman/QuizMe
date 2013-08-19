class EmailAskerMailer < ActionMailer::Base
  default from: "Wisr <wisr@app.wisr.com>"

  def question sender, recipient, text, question, short_url, options = {}
    @question = question
    @text = text
    @url = short_url
    mail(to: "#{recipient.twi_name} <#{recipient.email}>", from: sender.email, subject: @text, template_name: 'question')
  end

  def generic sender, recipient, text, short_url, options = {}
    @text = text
    @url = short_url
    m = mail(to: "#{recipient.twi_name} <#{recipient.email}>", from: sender.email, subject: options[:subject], template_name: 'message')
    return m, text, short_url
  end
end
