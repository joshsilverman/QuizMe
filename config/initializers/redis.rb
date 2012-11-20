if Rails.env.production?
	uri = URI.parse(ENV['REDISTOGO_URL'])
else
	uri = URI.parse('redis://localhost:6379')
end
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password, :username => uri.user)