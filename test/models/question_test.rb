require 'test_helper'

describe Question, "#update_answers" do
  it "stores answer in _answers attr" do
    question = create :question
    correct_answer = question.answers.correct

    question.update_answers

    question._answers.count.wont_be_nil
    question._answers.count.must_be :>, 0
    question._correct_answer_id.must_equal correct_answer.id
  end
end

describe Question, "#post" do
  let(:asker) { create :asker }
  let(:user) { create :user }

  let(:question) { create :question, asker: asker, user: user }
  let(:another_question) { create :question, asker: asker, user: user }
  let(:publication) { create :publication, asker: asker, question: question }

  let(:question_without_asker) { create :question, user: user }
  let(:question_without_user) { create :question, asker: asker }

  before do
    Delayed::Worker.delay_jobs = false
  end

  it 'calls send_public_message' do
    Asker.any_instance.expects :send_public_message
    question.post
  end

  it 'wont call send_public_message if user has no twitter screen name' do
    Asker.any_instance.expects(:send_public_message).never
    user.update twi_screen_name: nil
    question.post
  end

  it 'wont attempt send if no asker' do
    Asker.any_instance.expects(:send_public_message).never
    question_without_asker.post
  end

  it 'wont attempt send if no user' do
    Asker.any_instance.expects(:send_public_message).never
    question_without_user.post
  end

  it 'posts with link and question' do
    publication

    msg = "New question from @#{user.twi_screen_name}: #{question.text}"
    options = {
      long_url: "#{FEED_URL}/#{asker.subject_url}/#{publication.id}",
      question_id: question.id
    }
    Asker.any_instance.expects(:send_public_message).with msg, options
    question.post
  end

  it 'wont call if user has posted question in last n hours' do
    Asker.any_instance.expects(:send_public_message).never

    another_question
    question.post
  end
end

describe Question, "#recent_publication" do
  let(:asker) { create :asker }
  let(:user) { create :user }
  let(:question) { create :question, asker: asker, user: user }
  let(:publication) { create :publication, question: question }

  before do
    Delayed::Worker.delay_jobs = false
  end

  it 'returns publication if exists' do
    question
    publication

    question.recent_publication.must_equal publication
  end

  it 'returns most recent publication' do
    question
    publication

    Timecop.travel 1.day
    other_pub = create :publication, question: question

    question.recent_publication.must_equal other_pub
  end

  it 'creates publication on demand if none exists' do
    question
    recent_pub = question.recent_publication

    recent_pub.wont_be_nil
    recent_pub.asker.must_equal asker
    recent_pub._question.wont_be_nil
    recent_pub._answers.wont_be_nil
    recent_pub._asker.wont_be_nil
  end
end