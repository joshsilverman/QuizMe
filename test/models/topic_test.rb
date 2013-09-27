require 'test_helper'

describe Topic do
	let(:course) {create(:course, :with_lessons)}
	let(:lesson) {course.lessons.sort.first}
	let(:questions) {lesson.questions}
	let(:user) {create(:user)}
  let(:asker) do 
    asker = course.askers.first
    asker.followers << user
    asker
  end

	describe ".percentage_completed_by_user" do
		it 'is 0 when no questions have been answered correctly' do
			lesson.questions.count.must_equal 3
			lesson.percentage_completed_by_user(user).must_equal 0.0
		end

		it 'is 1 when all questions have been answered correctly' do
			questions.each {|q| create(:post, user: user, in_reply_to_user_id: asker.id, correct: true, interaction_type: 2, in_reply_to_question: q)}
			lesson.questions.count.must_equal 3
			lesson.percentage_completed_by_user(user).must_equal 1.0
		end

		it 'is .33 when one question has been answered correctly' do
			create(:post, user: user, in_reply_to_user_id: asker.id, correct: true, interaction_type: 2, in_reply_to_question: questions.first)
			lesson.percentage_completed_by_user(user).must_equal 1.0/3
		end

		it 'is .33 when one question has been answered correctly twice' do
			create(:post, user: user, in_reply_to_user_id: asker.id, correct: true, interaction_type: 2, in_reply_to_question: questions.first)
			create(:post, user: user, in_reply_to_user_id: asker.id, correct: true, interaction_type: 2, in_reply_to_question: questions.first)
			lesson.percentage_completed_by_user(user).must_equal 1.0/3
		end

		it 'is .33 when one question has been answered correctly once and incorrectly once' do
			create(:post, user: user, in_reply_to_user_id: asker.id, correct: true, interaction_type: 2, in_reply_to_question: questions.first)
			create(:post, user: user, in_reply_to_user_id: asker.id, correct: false, interaction_type: 2, in_reply_to_question: questions.first)
			lesson.percentage_completed_by_user(user).must_equal 1.0/3
		end
	end
end