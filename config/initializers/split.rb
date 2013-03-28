Split.configure do |config|
  config.db_failover = true # handle redis errors gracefully
  config.db_failover_on_db_error = proc{|error| Rails.logger.error(error.message) }
  config.allow_multiple_experiments = true
  config.enabled = true
  config.user_store = :redis_store
  config.robot_regex = /\b(Baidu|bot|BOT|Bot|butterfly|crawler|Crawler|expander|Gigabot|Googlebot|http|libwww-perl|lwp-trivial|msnbot|resolver|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)\b/i
  config.allowed_user_agent_regex = /Mozilla/
end

if REDIS.present?
	Split.redis = REDIS 
end