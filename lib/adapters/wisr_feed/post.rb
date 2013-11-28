module Adapters
  module WisrFeed
  end
end

module Adapters::WisrFeed::Post
  def self.save_or_update post
    request = build_request(post)
    send_request(request)
  end

  def self.http
    @@_http ||= Net::HTTP.new("feed.wisr.com")
  end

  def self.build_request post
    request = Net::HTTP::Post.new("api/users")
    request.set_form_data(post: post.attributes)

    request
  end

  def self.send_request request
    http.request(request)
  end
end