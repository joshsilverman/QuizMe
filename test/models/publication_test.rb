require 'test_helper'

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
  it "must set question and correct answer on publication" do
    asker = Asker.create
    question = Question.create text: 'What up?', asker: asker
    answer = question.answers.create text: 'correct ans', correct: true
    Question.stubs(:select_questions_to_post).returns [question.id]
    asker.stubs(:posts_per_day).returns 5

    PublicationQueue.enqueue_questions asker
    publication = Publication.first
    publication.update(_question: nil)
    publication.update_question
    
    publication.reload._question['question'].must_equal question.text
    publication._question['correct_answer'].must_equal question.answers.correct.text
  end

  it "must set incorrect answers" do
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

    publication.reload._question['incorrect_answer_0'].must_equal ans_0.text
    publication._question['incorrect_answer_1'].must_equal ans_1.text
    publication._question['incorrect_answer_2'].must_equal ans_2.text
  end
end