if Rails.env.production?
  Adapters::WisrFeed::URL = 'feed.wisr.com'
  Adapters::WisrFeed::AUTH_TOKEN = 'YjcJaCS3YK4ZsV1u9TE2'
  Adapters::WisrFeed::PORT = nil
else
  Adapters::WisrFeed::URL = 'feed.wisrdev.com'
  Adapters::WisrFeed::AUTH_TOKEN = 'VvzYYzJ36puS5GP4yG7m'
  Adapters::WisrFeed::PORT = 4000
end