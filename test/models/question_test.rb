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

  it 'creates a publication' do
    Timecop.freeze
    question.post

    Publication.count.must_equal 2

    pub = Publication.last
    pub.asker.id.must_equal asker.id
    pub.question.must_equal question
    pub._question.wont_be_nil
    pub._asker.wont_be_nil
    pub._answers.wont_be_nil
    pub._lesson.wont_be_nil

    pub.published.must_equal true
    pub.first_posted_at.to_i.must_equal Time.now.to_i

    Post.last.publication_id = pub.id
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

describe Question, "update_answer_counts" do
  let(:asker) { create :asker }
  let(:user) { create :user }
  let(:another_user) { create :user }
  let(:question) { create :question, asker: asker, user: user }
  let(:publication) { create :publication, question: question }

  it "updates count whith correct answer" do
    create :post, in_reply_to_question: question, correct: true

    question.update_answer_counts

    question._answer_counts.wont_be_nil
    question._answer_counts['correct'].must_equal "1"
    question._answer_counts['incorrect'].must_equal "0"
  end

  it "updates count whith in correct answer" do
    create :post, in_reply_to_question: question, correct: false

    question.update_answer_counts

    question._answer_counts.wont_be_nil
    question._answer_counts['correct'].must_equal "0"
    question._answer_counts['incorrect'].must_equal "1"
  end

  it "ignores non answer in reply to posts" do
    create :post, in_reply_to_question: question

    question.update_answer_counts

    question._answer_counts.wont_be_nil
    question._answer_counts['correct'].must_equal "0"
    question._answer_counts['incorrect'].must_equal "0"
  end

  it "wont double count with answers from multiple users" do
    create :post, in_reply_to_question: question, correct: true, user: user
    create :post, in_reply_to_question: question, correct: true, user: another_user

    question.update_answer_counts

    question._answer_counts.wont_be_nil
    question._answer_counts['correct'].must_equal "2"
  end

  it "wont double count answer from same user" do
    create :post, in_reply_to_question: question, correct: true, user: user
    create :post, in_reply_to_question: question, correct: true, user: user

    question.update_answer_counts

    question._answer_counts.wont_be_nil
    question._answer_counts['correct'].must_equal "1"
  end
end

describe Question, "send_answer_counts_to_publication" do
  let(:asker) { create :asker }
  let(:user) { create :user }
  let(:question) { create :question, asker: asker, user: user }
  let(:publication) { create :publication, question: question }
  let(:counts) { {"correct" => "1", "incorrect" => "2"} }

  it "copies answer counts into publication" do
    publication.update published: true 

    question.update _answer_counts: counts
    question.send_answer_counts_to_publication

    publication.reload._answer_counts.must_equal counts
  end

  it "wont copy answer counts into unpublished publication" do
    publication.update published: false 

    question.update _answer_counts: counts
    question.send_answer_counts_to_publication

    publication.reload._answer_counts.must_be_nil
  end
end