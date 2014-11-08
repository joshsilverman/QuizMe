require 'test_helper'

describe Publication, "#find_or_create_by_question_id" do
  it "returns a publication if question publication exists" do
    question = create :question
    publication = create :publication
    publication.update question: question

    found_publication = Publication.find_or_create_by_question_id question.id
    found_publication.must_equal publication
  end

  it "returns a new publication if question publication doesn't exists" do
    question = create :question

    found_publication = Publication.find_or_create_by_question_id question.id
    found_publication.question_id.must_equal question.id
  end

  it "wont create new publication if one already exists" do
    question = create :question
    publication = create :publication
    publication.update question: question

    found_publication = Publication.find_or_create_by_question_id question.id
    Publication.count.must_equal 1
  end

  it "returns a publication associated with proper asker if passed asker_id" do
    question = create :question

    found_publication = Publication.find_or_create_by_question_id question.id, 123
    found_publication.asker_id.must_equal 123
  end
end

describe Publication, '#update_activity' do
  it "must set activity and twi profile image on publication" do
    user = create :user
    post = Post.create user: user
    publication = Publication.create

    publication = publication.update_activity post

    publication._activity[user.twi_screen_name]
      .must_equal user.twi_profile_img_url
  end

  it "must allow activity for multiple users" do
    user1 = create :user
    post1 = Post.create user: user1

    user2 = create :user, twi_screen_name: '1', twi_profile_img_url: 'b.jpg'
    post2 = Post.create user: user2

    publication = Publication.create
    publication.update_activity post1

    publication = Publication.find(publication.id)
    publication.reload.update_activity post2
    
    publication = Publication.find(publication.id)

    publication._activity.keys.count.must_equal 2
    publication._activity[user1.twi_screen_name]
      .must_equal user1.twi_profile_img_url
    publication._activity[user2.twi_screen_name]
      .must_equal user2.twi_profile_img_url
  end
end

describe Publication, '#update_question' do
  it "must set question text and question id on publication" do
    asker = Asker.create
    question = Question.create text: 'What up?', asker: asker
    answer = question.answers.create text: 'correct ans', correct: true
    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker
    publication = Publication.first
    publication.update(_question: nil)
    publication.update_question
    
    publication.reload._question['text'].must_equal question.text
    publication._question['id'].must_equal question.id.to_s
  end

  it "must set correct answer id" do
    asker = Asker.create
    question = Question.create text: 'What up?', asker: asker
    answer = question.answers.create text: 'correct ans', correct: true
    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker
    publication = Publication.first
    publication.update(_question: nil)
    publication.update_question
    
    publication.reload._question['correct_answer_id']
      .must_equal question.answers.correct.id.to_s
  end

  it "must set twi twi_profile_img_url of asker" do
    asker = create :asker
    question = Question.create text: 'What up?', asker: asker
    answer = question.answers.create text: 'correct ans', correct: true
    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker
    publication = Publication.first
    publication.update(_question: nil)
    publication.update_question
    
    publication.reload._asker['id'].must_equal question.asker.id.to_s
    publication.reload._asker['twi_profile_img_url']
      .must_equal question.asker.twi_profile_img_url.to_s
    publication.reload._asker['subject']
      .must_equal question.asker.subject
    publication.reload._asker['subject_url']
      .must_equal question.asker.subject_url
  end

  it "must set answers with ids" do
    asker = Asker.create
    question = Question.create text: 'What up?', asker: asker
    ans_0 = question.answers.create text: 'incorrect ans 0', correct: false
    ans_1 = question.answers.create text: 'incorrect ans 1', correct: false
    ans_2 = question.answers.create text: 'incorrect ans 2', correct: false

    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker
    publication = Publication.first
    publication.update(_question: nil)
    publication.update_question

    publication.reload._answers[ans_0.id.to_s].must_equal ans_0.text
    publication.reload._answers[ans_1.id.to_s].must_equal ans_1.text
    publication.reload._answers[ans_2.id.to_s].must_equal ans_2.text
  end

  it "must set a lesson name and url if one exists" do
    asker = Asker.create
    question = Question.create text: 'What up?', asker: asker
    answer = question.answers.create text: 'correct ans', correct: true
    lesson = create :lesson
    lesson.questions << question

    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker
    publication = Publication.first
    publication.update(_question: nil)
    publication.update_question
    
    publication.reload._lesson['name'].must_equal lesson.name
    publication.reload._lesson['topic_url'].must_equal lesson.topic_url
  end

  it "must set author and created at info if present" do
    user = create :user
    asker = create :asker
    question = create :question, user: user, asker: asker
    publication = create :publication, question: question

    publication.update_question
    
    publication.reload._question['author_twi_screen_name'].wont_be_nil
    publication.reload._question['created_at'].wont_be_nil
  end

  it "wont set author info if not present" do
    asker = create :asker
    question = create :question, asker: asker
    publication = create :publication, question: question

    publication.update_question
    
    publication.reload._question['author_twi_screen_name'].must_be_nil
  end

  it "must set rating and rating count" do
    asker = create :asker
    question = create(:question, {
      asker: asker, 
      _rating: {'score' => '5.0', 'count' => '1'}})
    publication = create :publication, question: question

    publication.update_question
    
    publication.reload._question['rating'].must_equal '5.0'
    publication.reload._question['rating_count'].must_equal '1'
  end

  it "must defaults rating and rating count inteligently if no rating on question" do
    asker = create :asker
    question = create(:question, {asker: asker})
    publication = create :publication, question: question

    publication.update_question
    
    publication.reload._question['rating'].must_equal ''
    publication.reload._question['rating_count'].must_equal '0'
  end
end

describe Publication, ".inject_publication_by_id" do
  it "returns an array of publications" do
    publication = create :publication
    publications = Publication.all

    injected = Publication.inject_publication_by_id publications, nil

    injected.to_a.must_equal publications.to_a
  end

  it "will inject publication as first element if valid id provided" do
    asker = create :asker
    question = create :question, asker: asker
    publication = create :publication, question: question, asker: asker
    publications = Publication.limit 1
    injectable_pub = create :publication, question: question, asker: asker

    injected = Publication.inject_publication_by_id(publications, 
      injectable_pub.id.to_s)

    injected.to_a.must_equal Publication.all.order(created_at: :desc).to_a
  end

  it "will update publication if answers or asker nil" do
    asker = create :asker
    question = create :question, asker: asker
    publication = create :publication, question: question, asker: asker
    publications = Publication.limit 1
    injectable_pub = create :publication, question: question, asker: asker

    injected = Publication.inject_publication_by_id(publications, 
      injectable_pub.id.to_s).first
    
    injected._answers.wont_be_nil
    injected._asker.wont_be_nil
  end

  it "will set first posted at to created at if nil" do
    asker = create :asker
    question = create :question, asker: asker
    publication = create :publication, question: question, asker: asker
    publications = Publication.limit 1
    injectable_pub = create :publication, question: question, asker: asker
    injectable_pub.update first_posted_at: nil

    injected = Publication.inject_publication_by_id(publications, 
      injectable_pub.id.to_s).first

    injected.first_posted_at.must_equal injected.created_at
  end

  it "wont inject publication if the publication is included already" do
    publication = create :publication
    publications = Publication.limit 1

    injected = Publication.inject_publication_by_id(publications, 
      publication.id.to_s)

    injected.to_a.must_equal Publication.all.order(created_at: :desc).to_a
  end

  it 'wont error on invalid id' do
    publication = create :publication
    publications = Publication.limit 1

    injected = Publication.inject_publication_by_id(publications, 123123)

    injected.to_a.must_equal Publication.all.order(created_at: :desc).to_a
  end
end
