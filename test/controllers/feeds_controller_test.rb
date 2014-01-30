require 'test_helper'

describe FeedsController do

	def answer_question id = nil
		if id 
			post = page.find(".conversation[question_id=\"#{id}\"]")
		else
			post = page.find('.conversation')
		end

		post.click unless post[:class].split(' ').include?('active')
		assert post.has_selector?('.bottom_border')
		post.all('h3').first.click
		post.find('.tweet_button')
		post.all('.tweet_button').first.click
		assert post.has_selector?('.interactions')

		return post
	end

	before :each do 
		@user = create :user
		@admin = create :admin
		@asker = create :asker
		@asker.followers << @user	

		@question = create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)
		@publication = create(:publication, question: @question, asker: @asker)
		@question_post = create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)		
	end

	describe '#show routing' do
		it 'preserves publication id when redirecting' do
			asker = create(:asker, subject: 'Biology')
			question = create(:question)
			pub = create(:publication, question: question)

			visit "/feeds/#{asker.id}/#{pub.id}"

			current_url.must_equal "http://www.example.com/biology/#{pub.id}"
			status_code.must_equal 200
		end

		it 'redirects to subject when logged in' do
			login_as @user
			asker = create(:asker, subject: 'Biology')

			visit "/feeds/#{asker.id}"

			current_url.must_equal "http://www.example.com/biology"
			status_code.must_equal 200
		end

		it 'redirects to subject when not logged in' do
			asker = create(:asker, subject: 'Biology')

			visit "/feeds/#{asker.id}"

			current_url.must_equal "http://www.example.com/biology"
			status_code.must_equal 200
		end

		it 'redirects to subject with same querystring' do
			asker = create(:asker, subject: 'Biology')

			visit "/feeds/#{asker.id}?a=1"

			current_url.must_equal "http://www.example.com/biology?a=1"
			status_code.must_equal 200
		end

		it 'routes to show based on subject' do
			asker = create(:asker, subject: 'Biology')
			visit "/biology"

			status_code.must_equal 200
		end

		it 'redirects to root if no subject match' do
			asker = create(:asker, subject: 'Biology')
			visit "/blobology"

			current_path.must_equal '/'
			status_code.must_equal 200
		end
	end

	describe '#show' do
		before :each do
			Capybara.current_driver = :selenium
			login_as(@user, :scope => :user)
		end

		describe 'user answers question' do
			before :each do 
				visit "/feeds/#{@asker.id}"
				answer_question
			end
			
			it 'creates user post' do
				user_response = @user.posts.where(intention: 'respond to question').first
				user_response.in_reply_to_post_id.must_equal @question_post.id
			end

			it 'responds to user post' do
				grade_post = @asker.posts.where(intention: 'grade').first
				grade_post.in_reply_to_user_id.must_equal @user.id
			end
		end

		describe 'after answer requests' do
			describe 'question moderation' do
				it 'unless not requested publication' do
					visit "/feeds/#{@asker.id}"
					assert answer_question.has_no_selector?('.feedback')
				end

				it 'if requested publication' do
					visit "/feeds/#{@asker.id}/#{@publication.id}"
					assert answer_question.has_selector?('.feedback')
				end

				it 'unless question already has feedback' do
					@question.update(needs_edits: true)
					visit "/feeds/#{@asker.id}/#{@publication.id}"
					assert answer_question.has_no_selector?('.feedback')
				end

				it 'if user hasnt already provided a moderation' do
					create(:question_moderation, user_id: @user.id, question_id: @question.id, type_id: 7)
					visit "/feeds/#{@asker.id}/#{@publication.id}"
					assert answer_question.has_no_selector?('.feedback')
				end
			end

			describe 'email address' do
				before :each do 
					@user.update(email: nil)
				end
				
				it 'unless user has an email address' do
					@user.update(email: 'jason@jason.jason')
					visit "/feeds/#{@asker.id}"
					assert answer_question.has_no_selector?('.request_email')					
				end

				it "if user doesn't have an email address" do
					visit "/feeds/#{@asker.id}"
					assert answer_question.has_selector?('.request_email')
				end

				it "once a month" do
					3.times do |i|
						visit "/feeds/#{@asker.id}"
						answer_question(@question.id)
						page.all('.after_answer').count.must_equal ((i + 1) % 2)
						
						Timecop.travel(Time.now + (2.5).weeks)
						@question = create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)
						@publication = create(:publication, question: @question, asker: @asker)
						@question_post = create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)
						Rails.cache.clear
					end			
				end

				it "and updates user record properly" do
					visit "/feeds/#{@asker.id}"
					post = answer_question

					fill_in 'email_input', with: "This is my email"
					post.find('.request_email .btn').click
					assert post.find('.request_email input').visible?
					@user.reload.email.must_be_nil

					fill_in 'email_input', with: "jason@jason.jason"
					page.find('.request_email .btn').click
					assert post.has_no_selector?('.request_email input')
					@user.reload.email.must_equal "jason@jason.jason"
				end
			end
		end
	end
end

describe FeedsController, "#show_template" do
  it 'handles illegal post characters' do
		asker = create(:asker, subject: 'Biology')
		user = create(:user)
		feeds_controller = FeedsController.new
		feeds_controller.instance_variable_set(:@asker, asker)
		feeds_controller.stubs(:current_user).returns(user)
		feeds_controller.stubs(:params).returns(
			{post_id: "yummy\xE2 \xF0\x9F\x8D\x94 \x9F\x8D\x94"})
		feeds_controller.expects(:render)

		feeds_controller.send :show_template
	end
end

describe FeedsController, "#index" do
  it "responds with 200" do
    get :index
    response.status.must_equal 200
  end
end