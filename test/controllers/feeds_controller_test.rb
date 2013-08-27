require 'test_helper'

describe FeedsController do
	before :each do 
		@user = create :user
		@admin = create :admin
		@asker = create :asker
		@asker.followers << @user	

		@question = create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)
		@publication = create(:publication, question: @question, asker: @asker)
		@question_post = create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)		
	end

	describe 'routing' do
		it 'loads show when logged in' do
			login_as @user
			visit "/feeds/#{@asker.id}/#{@publication.id}"
		end

		it 'loads show when not logged in' do
			visit "/feeds/#{@asker.id}/#{@publication.id}"
		end
	end

	describe 'show' do
		before :each do
			Capybara.current_driver = :selenium
			login_as(@user, :scope => :user)	
		end

		describe 'user answers question' do
			before :each do 
				visit "/feeds/#{@asker.id}"
				post_elmnt = page.find(".post[post_id=\"#{@publication.id}\"]")
				post_elmnt.click
				post_elmnt.all('.answers h3').first.click
				sleep 1
				post_elmnt.all('.tweet_button').first.click
				page.find(".conversation[asker_id=\"#{@asker.id}\"] .subsidiary.answered")
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
					page.find('.post').click
					page.all('.answers h3').first.click
					sleep 1
					page.find('.tweet_button').click
					sleep 4
					page.all('.after_answer').count.must_equal 0
				end

				it 'if requested publication' do
					visit "/feeds/#{@asker.id}/#{@publication.id}"
					page.all('.answers h3').first.click
					sleep 1
					page.find('.tweet_button').click
					sleep 4
					page.find('.after_answer').visible?.must_equal true
				end

				it 'unless question already has feedback' do
					@question.update(needs_edits: true)
					visit "/feeds/#{@asker.id}/#{@publication.id}"
					page.all('.answers h3').first.click
					sleep 1
					page.find('.tweet_button').click
					sleep 4
					page.all('.after_answer').count.must_equal 0
				end

				it 'if user hasnt already provided a moderation' do
					create(:question_moderation, user_id: @user.id, question_id: @question.id, type_id: 7)
					visit "/feeds/#{@asker.id}/#{@publication.id}"
					page.all('.answers h3').first.click
					sleep 1
					page.find('.tweet_button').click
					sleep 4
					page.all('.after_answer').count.must_equal 0
				end
			end

			describe 'email address' do
				before :each do 
					@user.update(email: nil)
				end
				
				it 'unless user has an email address' do
					@user.update(email: 'jason@jason.jason')
					visit "/feeds/#{@asker.id}"
					page.find('.post').click
					page.all('.answers h3').first.click
					sleep 1
					page.find('.tweet_button').click
					sleep 4
					page.all('.after_answer').count.must_equal 0
				end

				it "if user doesn't have an email address" do
					visit "/feeds/#{@asker.id}"
					page.find('.post').click
					page.all('.answers h3').first.click
					sleep 1
					page.find('.tweet_button').click
					sleep 4
					page.all('.after_answer').count.must_equal 1
				end

				it "once per session" do 
					@question = create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)
					@publication = create(:publication, question: @question, asker: @asker)
					@question_post = create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)
					visit "/feeds/#{@asker.id}"

					page.all('.post').each do |post|
						post.click
						post.all('.answers h3').first.click
						sleep 1
						post.find('.tweet_button').click
						sleep 4
						page.all('.after_answer').count.must_equal 1
					end
				end

				it "once a month" do
					3.times do |i|
						visit "/feeds/#{@asker.id}"
						post_elmnt = page.find(".post[post_id=\"#{@publication.id}\"]")
						post_elmnt.click
						post_elmnt.all('.answers h3').first.click
						sleep 1
						post_elmnt.find('.tweet_button').click
						sleep 4
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
					post_elmnt = page.find(".post[post_id=\"#{@publication.id}\"]")
					post_elmnt.click
					post_elmnt.all('.answers h3').first.click; sleep 1
					post_elmnt.find('.tweet_button').click; sleep 4
					fill_in 'email_input', with: "This is my email"
					page.find('.request_email .btn').click; sleep 1
					@user.reload.email.must_be_nil
					fill_in 'email_input', with: "jason@jason.jason"
					page.find('.request_email .btn').click; sleep 1
					@user.reload.email.must_equal "jason@jason.jason"
				end
			end
		end
	end
end