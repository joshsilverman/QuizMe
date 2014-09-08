require 'test_helper'

describe FeedsController do
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

      get :show, id: asker.id, publication_id: pub.id

      response.header['Location'].must_equal "http://test.host/biology/#{pub.id}?"
      response.status.must_equal 301
    end

    it 'redirects to subject when logged in' do
      login_as @user
      asker = create(:asker, subject: 'Biology')

      get :show, id: asker.id

      response.header['Location'].must_equal "http://test.host/biology?"
      response.status.must_equal 301
    end

    it 'redirects to subject when not logged in' do
      asker = create(:asker, subject: 'Biology')

      get :show, id: asker.id

      response.header['Location'].must_equal "http://test.host/biology?"
      response.status.must_equal 301
    end

    it 'redirects to root if no subject match' do
      asker = create(:asker, subject: 'Biology')

      get :show, subject: "/blobology"

      response.header['Location'].must_equal "http://test.host/"
      response.status.must_equal 302
    end

    it 'redirects to the angular show based on subject' do
      asker = create(:asker, subject: 'Biology')

      get :show, subject: asker.subject_url

      response.header['Location'].must_equal "http://ng.dev.localhost/biology"
      response.status.must_equal 301
    end

    it 'redirects to the angular index' do
      asker = create(:asker, subject: 'Biology')

      get :index

      response.header['Location'].must_equal "http://ng.dev.localhost"
      response.status.must_equal 301
    end

    it 'redirects to the angular index with query string' do
      asker = create(:asker, subject: 'Biology')

      get :index, query_string: 'query_string'

      response.header['Location'].must_equal "http://ng.dev.localhost?query_string=query_string"
      response.status.must_equal 301
    end
  end

  describe '#new' do
    it 'returns questions formatted as publications' do
      get :new, subject: @asker.subject_url, format: :json

      response.status.must_equal 200
      JSON.parse(response.body).first['_question'].wont_be_nil
    end

    it 'restricts based on subject_url' do
      get :new, subject: 'different_subject', format: :json

      response.status.must_equal 404
    end

    it 'shows all new qs including ones that have not been published' do
      @question.update status: 0

      get :new, subject: @asker.subject_url, format: :json

      response.status.must_equal 200
      JSON.parse(response.body).count.must_equal 1
    end

    it 'accepts offset' do
      @question.update status: 0

      get :new, subject: @asker.subject_url, offset: 10, format: :json

      response.status.must_equal 200
      JSON.parse(response.body).count.must_equal 0
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
