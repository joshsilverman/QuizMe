workers Integer(ENV['PUMA_WORKERS'] || 3)
threads Integer(ENV['MIN_THREADS']  || 1), Integer(ENV['MAX_THREADS'] || 16)

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
  # worker specific setup
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::Base.establish_connection
  end
end

PumaWorkerKiller.config do |config|
  config.ram           = ENV['PUMA_RAM'] || 512
  config.frequency     = 60*5
  config.percent_usage = 0.95
end

PumaWorkerKiller.start