require 'test_helper'

describe QuestionsController do
	before :each do
		@author = create(:user, twi_user_id: 1, role: 'user')
		@asker = create(:asker)
		@asker.followers << @author
		@question = create(:question, created_for_asker_id: @asker.id, status: -1, user: @author, inaccurate: true, ungrammatical: true, bad_answers: true)
	end

	describe 'update' do
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