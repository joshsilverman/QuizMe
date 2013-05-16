# config/initializers/carrierwave.rb
CarrierWave.configure do |config|
  config.cache_dir = "#{Rails.root}/tmp/"
  config.storage = :fog
  config.permissions = 0666
  config.fog_credentials = {
    :provider               => 'AWS',
    :aws_access_key_id      => 'AKIAIDQNX4IECM24XAEQ',
    :aws_secret_access_key  => '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',
  }
  config.fog_directory  = 'wisr-sitemap'
end