require 'test_helper'

describe QuestionsController do
	before :each do
		@author = create(:user, twi_user_id: 1, role: 'user')
		@asker = create(:asker)
		@asker.followers << @author
		@question = create(:question, created_for_asker_id: @asker.id, status: -1, user: @author, inaccurate: true, ungrammatical: true, bad_answers: true)
	end

	describe '#show' do
		it 'gets with status 301 and redirects to new feed' do
			pub = create :publication, question: @question, asker: @asker
			get :show, id: @question.id
			response.status.must_equal 301
			response.location.must_equal "http://ng.dev.localhost/#{@asker.subject_url}/#{pub.id}"
		end

		it 'redirects to home if no publication for question' do
			get :show, id: @question.id
			response.status.must_equal 302
		end
	end

	describe '#update' do
		before :each do
			Capybara.current_driver = :selenium
			login_as @author
			visit "/askers/#{@asker.id}/questions"
		end

		it 'sets question to pending when edited' do
			@question.update(status: 1)
			bip_area @question, :text, "sup homeboy? this is now my question."
			sleep 1
			@question.reload.status.must_equal 0
		end

		it 'clears question feedback when question edited' do
			@question.inaccurate.must_equal true
			@question.ungrammatical.must_equal true
			bip_area @question, :text, "sup homeboy? this is now my question."
			sleep 1
			@question.reload.inaccurate.must_equal nil
			@question.ungrammatical.must_equal nil
		end

		it 'clears answer feedback when answers edited' do
			@question.bad_answers.must_equal true
			bip_text @question.answers.first, :text, "new answer!"
			sleep 1
			@question.reload.bad_answers.must_equal nil
		end
	end
end

describe QuestionsController, "#count" do
  it "return the number of questions authored" do
  	user = create :user
  	question = create :question, user_id: user.id

    get :count, user_id: user.id, format: :json

    response.body.must_equal('1')
  end
end

describe QuestionsController, "#save_question_and_answers" do
	let(:user) { create(:user) }
	let(:asker) { create(:asker) }

	let(:params) {
		{ asker_id: asker.id,
			question: 'What is the what?',
			canswer: 'The what'
		}
	}

	it "creates a new question" do
		sign_in user

		post :save_question_and_answers, params

		response.status.must_equal 200
		Question.count.must_equal 1
	end

	it "creates a correct answer" do
		sign_in user

		post :save_question_and_answers, params

		response.status.must_equal 200
		Answer.count.must_equal 1
		Answer.first.text.must_equal "The what"
	end

	it "wont create a new question if user not authed" do
		post :save_question_and_answers, params

		response.status.must_equal 302
		Question.count.must_equal 0
	end

	it "wont create a new question if user no question passed" do
		sign_in user
		params.delete :question

		post :save_question_and_answers, params

		Question.count.must_equal 0
	end


	it "wont create a new question if user no correct answer passed" do
		sign_in user
		params.delete :canswer

		post :save_question_and_answers, params

		Question.count.must_equal 0
	end

	it "will set status to unapproved" do
		sign_in user
		post :save_question_and_answers, params

		Question.last.status.must_equal 0
	end

	it "will save incorrect answer" do
		sign_in user
		params[:ianswer1] = "The who"

		post :save_question_and_answers, params
		Answer.count.must_equal 2
		Answer.where(text: "The who").count.must_equal 1
	end

	it "will ignore blank answer"do
		sign_in user
		params[:ianswer1] = ""

		post :save_question_and_answers, params
		Answer.count.must_equal 1
	end

	it "will cache answers"do
		sign_in user
		params[:ianswer1] = ""

		post :save_question_and_answers, params
		Question.last._answers.wont_equal nil
	end
end
