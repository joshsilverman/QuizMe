REDIS = nil
if ENV['REDISCLOUD_URL'].present?
	uri = URI.parse(ENV["REDISCLOUD_URL"])
	REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end