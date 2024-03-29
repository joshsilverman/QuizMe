require 'test_helper'

describe Post, ".publish" do
  it "sends with correct url" do
    asker = create(:asker)
    question = create(:question)
    publication = create(:publication, 
      asker: asker,
      question: question)

    Post.publish("twitter", asker, publication)
    uri = URI.parse Post.first.url

    uri.path.must_equal "/#{asker.subject_url}/#{publication.id}"
  end
end

describe Post, "#link_to_question" do
  it "method defined by module" do
    dm = build(:dm, text: 'true')

    dm.methods.must_include :link_to_question
  end
end

describe Post, '#send_to_stream' do
  it 'calls stream socket' do
    post = FactoryGirl.create(:post)
    post.update in_reply_to_question: FactoryGirl.create(:question)
    post.update user: FactoryGirl.create(:user)
    post.update in_reply_to_user: FactoryGirl.create(:asker)

    stream_post = {
      "created_at" => post.created_at,
      "in_reply_to_question" => {
        "id" => post.in_reply_to_question.id,
        "text" => post.in_reply_to_question.text
        },
      "user" => {
        "twi_screen_name" => post.user.twi_screen_name,
        "twi_profile_img_url" => post.user.twi_profile_img_url
      }
    }

    stream = mock()
    stream.expects(:trigger).with('answer', stream_post)
    Pusher.expects(:[]).with('stream').returns(stream)

    post.send_to_stream
  end
end

describe Post, '.twitter_request' do
  it 'returns empty array when passed block in test env' do
    Post.twitter_request {}.must_equal []
  end

  it 'returns empty array when passed message and block in test env' do
    Post.twitter_request('hey hey') {}.must_equal []
  end
end

describe Post, '#send_to_publication' do
  it 'calls update activity on correct publication with post' do
    question = Question.create
    publication = Publication.create question: question, published: true
    post = Post.create in_reply_to_question: question

    Publication.any_instance.expects(:update_activity).with(post)

    post.send_to_publication
  end

  it 'returns nil if no publication found' do
    post = Post.create
    post.send_to_publication.must_equal nil
  end

  it 'returns the latest publication if multiple publications exist' do
    question = Question.create
    publication_0 = Publication.create({ 
      question: question, 
      created_at: 4.days.ago,
      published: true})
      
    publication_1 = Publication.create({ 
      question: question, 
      created_at: 1.day.ago,
      published: true})
      
    publication_2 = Publication.create({ 
      question: question, 
      created_at: 2.days.ago,
      published: true})
      
    post = Post.create in_reply_to_question: question

    Publication.any_instance.expects(:update_activity).with(post)

    post.send_to_publication.must_equal publication_1
  end

  it 'wont call update activity on pub if unpublished' do
    question = Question.create
    publication = Publication.create question: question
    post = Post.create in_reply_to_question: question

    Publication.any_instance.expects(:update_activity).with(post).never

    post.send_to_publication
  end
end