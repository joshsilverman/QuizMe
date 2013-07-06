class EmailAskerMailer < ActionMailer::Base
  default :from => "Wisr <wisr@app.wisr.com>"

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
    m = mail(to: "Josh <#{recipient.email}>", from: sender.email, subject: @text, template_name: 'question')
    return m, text, short_url
  end
end
