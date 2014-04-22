require 'test_helper'

describe FeedsController do

  def answer_question id = nil
    if id 
      post = page.find(".feed-publication[question-id=\"#{id}\"]")
    else
      post = page.find('.feed-publication')
    end

    post.all('.answer').first.click
    assert post.has_selector?('.answer.correct, .answer.incorrect')

    return post
  end

  before :each do 
    @user = create :user
    @admin = create :admin
    @asker = create :asker
    @asker.followers << @user 

    @question = create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)
    @publication = create(:publication, question: @question, asker: @asker, published: true)
    @publication.update_question

    @question_post = create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)   
  end

  describe '#show routing' do
    it 'preserves publication id when redirecting' do
      asker = create(:asker, subject: 'Biology')
      question = create(:question)
      pub = create(:publication, question: question)

      visit "/feeds/#{asker.id}/#{pub.id}"

      current_url.must_equal "http://www.example.com/biology/#{pub.id}"
      status_code.must_equal 200
    end

    it 'redirects to subject when logged in' do
      login_as @user
      asker = create(:asker, subject: 'Biology')

      visit "/feeds/#{asker.id}"

      current_url.must_equal "http://www.example.com/biology"
      status_code.must_equal 200
    end

    it 'redirects to subject when not logged in' do
      asker = create(:asker, subject: 'Biology')

      visit "/feeds/#{asker.id}"

      current_url.must_equal "http://www.example.com/biology"
      status_code.must_equal 200
    end

    it 'redirects to subject with same querystring' do
      asker = create(:asker, subject: 'Biology')

      visit "/feeds/#{asker.id}?a=1"

      current_url.must_equal "http://www.example.com/biology?a=1"
      status_code.must_equal 200
    end

    it 'routes to show based on subject' do
      asker = create(:asker, subject: 'Biology')
      visit "/biology"

      status_code.must_equal 200
    end

    it 'redirects to root if no subject match' do
      asker = create(:asker, subject: 'Biology')
      visit "/blobology"

      current_path.must_equal '/'
      status_code.must_equal 200
    end
  end

  describe '#show' do
    before :each do
      Capybara.current_driver = :selenium
    end

    describe 'click an answer when logged in' do
      before :each do 
        login_as(@user, :scope => :user)

        visit "/#{@asker.subject_url}"
  
        answer_question
      end
      
      it 'creates user post' do
        user_response = @user.posts.where(intention: 'respond to question').first
        user_response.in_reply_to_post_id.must_equal @question_post.id
      end

      it 'responds to user post' do
        grade_post = @asker.posts.where(intention: 'grade').first
        grade_post.in_reply_to_user_id.must_equal @user.id
      end
    end

    describe 'click an answer when not logged in' do
      before :each do 
        visit "/#{@asker.subject_url}"
      end
      
      it 'takes user to authentication page' do
        page.all('.content .answer').first.click
        current_path.must_equal '/oauth/authenticate'
      end
    end
  end
end

describe FeedsController, "#respond_to_question" do
  it "creates a post on the fly if question never posted" do
    user = create :user
    # pub = create :publication
    asker = create :asker
    q = create :question, asker: asker

    sign_in user
    post(:respond_to_question, 
      asker_id: asker.id,
      answer_id: q.answers.first)

    response.status.must_equal 200

    post = Conversation.last.post
    post.wont_be_nil
    post.question_id.must_equal q.id
    post.user_id.must_equal asker.id
  end
end

describe FeedsController, "#index" do
  it "responds with 200" do
    get :index
    response.status.must_equal 200
  end
end