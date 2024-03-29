# ActionMailer::Base.smtp_settings = {
#   :address              => "smtp.gmail.com",
#   :port                 => 587,
#   :domain               => "studyegg.com",
#   :user_name            => "jsilverman@studyegg.com",
#   :password             => "GlJnb@n@n@",
#   :authentication       => "plain",
#   :enable_starttls_auto => true
# }

ActionMailer::Base.smtp_settings = {
  :address        => 'smtp.sendgrid.net',
  :port           => '587',
  :authentication => :plain,
  :user_name      => ENV['SENDGRID_USERNAME'],
  :password       => ENV['SENDGRID_PASSWORD'],
  :domain         => 'app.wisr.com',
  :enable_starttls_auto => true
}

ActionMailer::Base.default_url_options[:host] = "wisr.com"
#Mail.register_interceptor(DevelopmentMailInterceptor) if Rails.env.development

Quizmemanager::Application.configure do
  # extend assets path for roadie
  config.assets.paths << Rails.root.join('public', 'assets')
end