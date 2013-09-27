class EmailAskerMailer < ActionMailer::Base
  default from: "Wisr <wisr@app.wisr.com>"

  def question sender, recipient, text, question, short_url, options = {}
    @question = question
    @text = text
    @url = short_url
    @include_answers = options[:include_answers]
    @grade = nil
    @course = sender.select_course recipient
    @lessons = @course.lessons.sort
    @recipient = recipient

    if options[:intention] == 'grade'
      @grade = text
      @text = "Next question: #{question.text}"
      mail(to: "#{recipient.twi_name} <#{recipient.email}>", from: sender.email, subject: 'Re: Next question:', template_name: 'question')
    else
      mail(to: "#{recipient.twi_name} <#{recipient.email}>", from: sender.email, subject: 'Next question:', template_name: 'question')
    end
  end

  def generic sender, recipient, text, short_url, options = {}
    @text = text
    @url = short_url
    mail(to: "#{recipient.twi_name} <#{recipient.email}>", from: sender.email, subject: options[:subject], template_name: 'message')
  end
end
