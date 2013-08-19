class EmailAskerMailer < ActionMailer::Base
  # default :from => "Wisr <wisr@app.wisr.com>"
  default from: "Wisr <app6915090@heroku.com>"

  def question sender, recipient, text, question, options = {}
    short_url = nil
    if options[:short_url]
      short_url = options[:short_url]
    elsif options[:long_url]
      short_url = Post.format_url(options[:long_url], 'email', options[:link_type], sender.twi_screen_name, recipient.twi_screen_name) 
    end

    @question = question
    @text = text
    @url = short_url
    m = mail(to: "#{recipient.twi_name} <#{recipient.email}>", from: sender.email, subject: @text, template_name: 'question')
    return m, text, short_url
  end

  def generic sender, recipient, text, options = {}
    short_url = nil
    if options[:short_url]
      short_url = options[:short_url]
    elsif options[:long_url]
      short_url = Post.format_url(options[:long_url], 'email', options[:link_type], sender.twi_screen_name, recipient.twi_screen_name) 
    end

    @text = text
    @url = short_url
    m = mail(to: "#{recipient.twi_name} <#{recipient.email}>", from: sender.email, subject: options[:subject], template_name: 'message')
    return m, text, short_url
  end
end
