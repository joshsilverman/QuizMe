require 'test_helper'

describe Adapters::WisrFeed::Post, '.save_or_update' do

  it 'makes request with post' do
    disable_after_save_post_observer
    post = FactoryGirl.create(:post)

    Adapters::WisrFeed::Post.expects(:build_request).with(post)
    Adapters::WisrFeed::Post.expects(:send_request)

    Adapters::WisrFeed::Post::save_or_update post
  end
end

describe Adapters::WisrFeed::Post, ".build_request" do
  before :each do
    disable_after_save_post_observer
  end

  it "should return request obj with correct path" do

    post = FactoryGirl.create :post
    request = Adapters::WisrFeed::Post::build_request post

    request.path.must_equal '/api/posts/create_or_update'
    request.must_be_kind_of Net::HTTP::Post
  end

  it "should set http object on Post obj" do
    post = FactoryGirl.create :post

    request = Adapters::WisrFeed::Post::build_request post
    Adapters::WisrFeed::Post::http.must_be_kind_of Net::HTTP
  end

  it "should return request with post vars" do
    text = 'alksjdfhalkjshdfkajfhdslkajsfh'
    post = FactoryGirl.create(:post, text: text)

    request = Adapters::WisrFeed::Post::build_request post
    Adapters::WisrFeed::Post::http.must_be_kind_of Net::HTTP

    request.body.must_include text
  end
end

describe Adapters::WisrFeed::Post, ".send_request" do
  it "should hit /api/posts/save_or_update endpoint" do
    disable_after_save_post_observer
    post = FactoryGirl.create :post
    request = Adapters::WisrFeed::Post::build_request post
    
    Adapters::WisrFeed::Post::http.expects(:request).with(request)

    response = Adapters::WisrFeed::Post::send_request request
  end
end

describe Adapters::WisrFeed::Post, ".post_params" do
  it "should returns hash with appropriate keys" do
    disable_after_save_post_observer
    post = FactoryGirl.create :post, text: 'abc'
    params = Adapters::WisrFeed::Post::post_params post
    
    params["post[text]"].must_equal "abc"
  end
end

def disable_after_save_post_observer
  PostObserver.any_instance.stubs(:after_save)
end