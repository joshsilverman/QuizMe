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
    @@_http ||= Net::HTTP.new(Adapters::WisrFeed::URL, Adapters::WisrFeed::PORT)
  end

  def self.build_request post
    request = Net::HTTP::Post.new("/api/posts/create_or_update")
    request.set_form_data(post_params(post))

    request
  end

  def self.send_request request
    http.request(request)
  end

  def self.post_params post
    post_params = {auth_token: Adapters::WisrFeed::AUTH_TOKEN}
    post.attributes.map do |key, value|
      post_params["post[#{key}]"] = value
    end

    post_params
  end
end