# uri = URI.parse(ENV['REDISTOGO_URL'])
uri = URI.parse('redis://localhost:6379')
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password, :username => uri.user)