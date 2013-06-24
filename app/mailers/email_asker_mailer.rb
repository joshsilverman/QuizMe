class EmailAskerMailer < ActionMailer::Base
  default :from => "jsilverman@studyegg.com"

  def question sender, recipient, text, question, options = {}
    short_url = nil
    if options[:short_url]
      short_url = options[:short_url]
    elsif options[:long_url]
      short_url = Post.format_url(options[:long_url], 'email', options[:link_type], sender.twi_screen_name, recipient.twi_screen_name) 
    end

    @question = question
    @text = text + ' '
    @text = "#{text} #{short_url}" if options[:include_url] and short_url
    from = "#{sender.twi_screen_name} <jsilverman@studyegg.com>"
    m = mail(to: "Josh <#{recipient.email}>", from: from, subject: @text, template_name: 'question')
    return m, text, short_url
  end
end
