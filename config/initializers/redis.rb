# puts ENV["REDISTOGO_URL"]
# if Rails.env.production?
# 	uri = URI.parse(ENV['REDISTOGO_URL'])
# else
# 	uri = URI.parse('redis://localhost:6379')
# end
REDIS = nil
puts Rails.env
if ENV['REDISTOGO_URL'].present?
	puts ENV['REDISTOGO_URL']
	uri = URI.parse(ENV['REDISTOGO_URL'])
	puts uri.to_json
	REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password, :username => uri.user)
	puts REDIS.to_json
end