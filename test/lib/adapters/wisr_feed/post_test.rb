require 'test_helper'

describe Post, '.save_or_update' do

  it 'makes request with post' do
    user = User.create role: 'asker'
    question = FactoryGirl.create :question
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, user: user, 
                                     question: question, 
                                     publication: publication

    Adapters::WisrFeed::Post.expects(:build_request).with(post)
    Adapters::WisrFeed::Post.expects(:send_request)

    Adapters::WisrFeed::Post::save_or_update post
  end

  it 'wont send request if improper arguments provided' do
    question = FactoryGirl.create :question
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, question: question, 
                                     publication: publication

    Adapters::WisrFeed::Post.expects(:send_request).never

    Adapters::WisrFeed::Post::save_or_update post
  end
end

describe Post, ".build_request" do
  before :each do
    ActiveRecord::Base.observers.disable :all
  end

  it "should return request obj with correct path" do
    user = User.create role: 'asker'
    question = FactoryGirl.create :question
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, user: user, 
                                     question: question, 
                                     publication: publication

    request = Adapters::WisrFeed::Post::build_request post

    request.path.must_equal '/api/asker_feeds'
    request.must_be_kind_of Net::HTTP::Post
  end

  it "should set http object on Post obj" do
    user = User.create role: 'asker'
    question = FactoryGirl.create :question
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, user: user, 
                                     question: question, 
                                     publication: publication

    request = Adapters::WisrFeed::Post::build_request post
    Adapters::WisrFeed::Post::http.must_be_kind_of Net::HTTP
  end

  it "should return request with post vars" do
    text = 'alksjdfhalkjshdfkajfhdslkajsfh'

    user = User.create role: 'asker'
    question = FactoryGirl.create :question, text: text
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, user: user, 
                                     question: question, 
                                     publication: publication

    request = Adapters::WisrFeed::Post::build_request post
    Adapters::WisrFeed::Post::http.must_be_kind_of Net::HTTP

    request.body.must_include text
  end

  it "should raise error if user not asker" do
    user = User.create role: 'user'
    question = FactoryGirl.create :question
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, user: user, 
                                     question: question, 
                                     publication: publication

    -> { Adapters::WisrFeed::Post::build_request post }.must_raise ArgumentError
  end
end

describe Post, ".send_request" do
  it "should hit /api/posts/create_or_update endpoint" do
    question = FactoryGirl.create :question, text: "what?"
    publication = FactoryGirl.create :publication
    user = User.new twi_name: 'Bubba', role: 'asker'
    post = FactoryGirl.create :post, question: question, 
                                     publication: publication,
                                     user: user

    request = Adapters::WisrFeed::Post::build_request post
    
    Adapters::WisrFeed::Post::http.expects(:request).with(request)

    response = Adapters::WisrFeed::Post::send_request request
  end
end

describe Post, ".post_params" do
  before :each do
    ActiveRecord::Base.observers.disable :all
  end

  it 'should raise argument error if if no question defined' do
    post = FactoryGirl.create :post

    -> { Adapters::WisrFeed::Post::post_params post }.must_raise ArgumentError
  end

  it 'should raise argument error if no correct answer defined' do
    question = Question.create(text: "what?")
    post = FactoryGirl.create :post, question: question

    -> { Adapters::WisrFeed::Post::post_params post }.must_raise ArgumentError
  end

  it 'should raise no publication if no publication defined' do
    question = FactoryGirl.create :question, text: "what?"
    post = FactoryGirl.create :post, question: question

    -> { Adapters::WisrFeed::Post::post_params post }.must_raise ArgumentError
  end

  it "should returns hash with question key and value" do
    question = FactoryGirl.create :question, text: "what?"
    publication = FactoryGirl.create :publication
    user = User.new twi_name: 'Bubba', role: 'asker'
    post = FactoryGirl.create :post, question: question, 
                                     publication: publication,
                                     user: user
    params = Adapters::WisrFeed::Post::post_params post
    
    params_hash = Hash[params.group_by(&:first).map{ |k,a| [k,a.map(&:last)] }]
    params_hash["asker_feed[post][question]"].first.must_equal "what?"
  end

  it "should returns hash with correct answer" do
    question = FactoryGirl.create :question
    question.answers.correct.update(text: 'ans')
    publication = FactoryGirl.create :publication
    user = User.new twi_name: 'Bubba', role: 'asker'
    post = FactoryGirl.create :post, question: question, 
                                     publication: publication,
                                     user: user

    params = Adapters::WisrFeed::Post::post_params post
    
    params_hash = Hash[params.group_by(&:first).map{ |k,a| [k,a.map(&:last)] }]
    params_hash["asker_feed[post][correct_answer]"].first.must_equal "ans"
  end

  it "should returns hash with false answers" do
    user = User.new twi_name: 'Bubba', role: 'asker'
    question = FactoryGirl.create :question
    incorrect_answers = question.answers.incorrect
    incorrect_answers_text = incorrect_answers.collect &:text
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, user: user, 
                                     question: question, 
                                     publication: publication

    params = Adapters::WisrFeed::Post::post_params post
    
    params_hash = Hash[params.group_by(&:first).map{ |k,a| [k,a.map(&:last)] }]
    params_hash["asker_feed[post][false_answers][]"]
      .must_equal incorrect_answers_text
  end

  it "should returns hash with publication id set as wisr_id" do
    user = User.new twi_name: 'Bubba', role: 'asker'
    question = FactoryGirl.create :question
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, user: user, 
                                     question: question, 
                                     publication: publication

    params = Adapters::WisrFeed::Post::post_params post
    
    params_hash = Hash[params.group_by(&:first).map{ |k,a| [k,a.map(&:last)] }]
    params_hash["asker_feed[post][wisr_id]"].first.must_equal publication.id
  end

  it "should include user details" do
    user = User.new twi_name: 'Bubba', role: 'asker'
    question = FactoryGirl.create :question
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, user: user, 
                                     question: question, 
                                     publication: publication

    params = Adapters::WisrFeed::Post::post_params post
    
    params_hash = Hash[params.group_by(&:first).map{ |k,a| [k,a.map(&:last)] }]
    params_hash["asker_feed[twi_name]"].first.must_equal "Bubba"
  end

  it "should include user id" do
    user = User.create twi_name: 'Bubba', role: 'asker'
    question = FactoryGirl.create :question
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, user: user, 
                                     question: question, 
                                     publication: publication

    params = Adapters::WisrFeed::Post::post_params post
    
    params_hash = Hash[params.group_by(&:first).map{ |k,a| [k,a.map(&:last)] }]
    params_hash["asker_feed[wisr_id]"].first.must_equal user.id
  end

  it "should include created_at" do
    user = User.create twi_name: 'Bubba', role: 'asker'
    question = FactoryGirl.create :question
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, user: user, 
                                     question: question, 
                                     publication: publication

    params = Adapters::WisrFeed::Post::post_params post
    
    params_hash = Hash[params.group_by(&:first).map{ |k,a| [k,a.map(&:last)] }]
    params_hash["asker_feed[post][created_at]"].first.to_i
      .must_equal post.created_at.to_i
  end

  it "should raise non asker exception if user nil" do
    question = FactoryGirl.create :question
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, question: question, 
                                     publication: publication

    -> { Adapters::WisrFeed::Post::post_params(post) }.must_raise ArgumentError
  end

  it "should raise non asker exception if user not asker" do
    user = User.create twi_name: 'Bubba', role: 'user'
    question = FactoryGirl.create :question
    publication = FactoryGirl.create :publication
    post = FactoryGirl.create :post, user: user, 
                                     question: question, 
                                     publication: publication

    -> { Adapters::WisrFeed::Post::post_params(post) }.must_raise ArgumentError
  end
end