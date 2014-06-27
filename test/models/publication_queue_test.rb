require 'test_helper'

describe PublicationQueue, ".enqueue_questions" do
  it "has correct basic attrs" do
    asker = create :asker
    question = Question.create text: 'What up?', asker: asker
    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker

    Publication.count.must_equal 1
    Publication.first.question_id.must_equal question.id
    Publication.first.asker_id.must_equal asker.id
  end

  it "stores question in hstore cache" do
    asker = create :asker
    question = Question.create text: 'What up?', asker: asker
    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker

    Publication.count.must_equal 1
    Publication.first._question['text'].must_equal question.text
  end

  it "stores correct answer in hstore cache" do
    asker = create :asker
    question = Question.create text: 'What up?', asker: asker
    answer = question.answers.create text: 'correct ans', correct: true
    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker

    Publication.count.must_equal 1
    Publication.first._answers[answer.id.to_s].must_equal answer.text
  end

  it "stores incorrect answers in hstore cache" do
    asker = create :asker
    question = Question.create text: 'What up?', asker: asker
    ans_0 = question.answers.create text: 'incorrect ans 0', correct: false
    ans_1 = question.answers.create text: 'incorrect ans 1', correct: false
    ans_2 = question.answers.create text: 'incorrect ans 2', correct: false
    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker

    Publication.count.must_equal 1
    Publication.first._answers[ans_0.id.to_s].must_equal ans_0.text
    Publication.first._answers[ans_1.id.to_s].must_equal ans_1.text
    Publication.first._answers[ans_2.id.to_s].must_equal ans_2.text
  end
end

describe PublicationQueue, ".dequeue_question" do
  it "updates publication queue id" do
    asker = create :asker
    question = create :question
    publication = create :publication, publication_queue_id: 123
    question.publications << publication

    publication.publication_queue_id.wont_equal nil
    PublicationQueue.dequeue_question asker.id, question.id

    publication.reload.publication_queue_id.must_equal nil
  end
end

describe PublicationQueue, ".clear_queue" do
  it "updates publication queue id" do
    asker = create :asker
    queue = PublicationQueue.create asker: asker
    publication = create :publication, publication_queue_id: 123
    queue.publications << publication

    publication.publication_queue_id.wont_equal nil
    PublicationQueue.clear_queue asker

    publication.reload.publication_queue_id.must_equal nil
  end
end

describe PublicationQueue, "#increment_index" do
  it "increments index" do
    queue = PublicationQueue.create index: 0

    queue.increment_index 5

    queue.reload.index.must_equal 1
  end

  it "resets index to 0 if whole queue has been cycled through" do
    queue = PublicationQueue.create index: 2

    queue.increment_index 3

    queue.reload.index.must_equal 0
  end
end