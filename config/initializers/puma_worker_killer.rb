PumaWorkerKiller.config do |config|
  config.ram           = ENV['PUMA_RAM'] || 512
  config.frequency     = 60*5
  config.percent_usage = 0.95
end

PumaWorkerKiller.start