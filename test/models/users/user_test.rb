require 'test_helper'

describe User, 'CRUD' do
  describe '#save' do
    it 'saves records with large :twi_user_id' do
      user = User.find_or_create_by(twi_user_id: 2210874654)

      user.valid?.must_equal true
    end
  end
end

describe User do  
  before :each do 
    Rails.cache.clear
    ActiveRecord::Base.observers.enable :post_moderation_observer

    @asker = create(:asker)
    @user = create(:user, twi_user_id: 1)

    @asker.followers << @user   

    @question = create(:question, created_for_asker_id: @asker.id, status: 1)   
    @publication = create(:publication, question_id: @question.id)
    @question_status = create(:post, user_id: @asker.id, interaction_type: 1, question_id: @question.id, publication_id: @publication.id)   

    @user_response = create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @question.id)
  end

  describe "transitions" do
    describe 'lifecycle' do
      it 'between noob => superuser' do
        Timecop.travel(Time.now.beginning_of_year + 7.days)
        Timecop.travel(Time.now.beginning_of_week)
        5.times do
          create(:correct_response, user: @user)
          @user.segment

        end
        30.times do |i|
          create(:correct_response, user: @user)
          @user.segment

          if i >= 28 
            @user.reload.lifecycle_above? 5
          elsif i >= 14
            @user.reload.lifecycle_above? 4
          elsif i >= 7
            @user.reload.lifecycle_above? 3
          else
            @user.reload.lifecycle_segment.must_equal 7
          end

          Timecop.travel(Time.now + 1.day)
        end
      end
    end 

    describe "post moderation" do
      before :each do
        @user = FactoryGirl.create(:user, twi_user_id: 1)
        @moderator = FactoryGirl.create(:moderator, twi_user_id: 1, role: 'moderator')
        @asker = FactoryGirl.create(:asker)
        @asker.followers << [@user, @moderator]

        @question = FactoryGirl.create(:question, created_for_asker_id: @asker.id, status: 1, user: @user)    
        @publication = FactoryGirl.create(:publication, question: @question, asker: @asker)
        @post_question = FactoryGirl.create(:post, user_id: @asker.id, interaction_type: 1, question: @question, publication: @publication)   
        @conversation = FactoryGirl.create(:conversation, post: @post_question, publication: @publication)
      end

      it 'to supermod only if high enough lifecycle segment' do
        100.times do 
          post = FactoryGirl.create :post, 
            user: @user, 
            requires_action: true, 
            in_reply_to_post_id: @post_question.id,
            in_reply_to_user_id: @asker.id,
            in_reply_to_question_id: @question.id,
            interaction_type: 2, 
            conversation: @conversation
          FactoryGirl.create(:post_moderation, type_id:1, accepted: true, user_id: @moderator.id, post_id: post.id)
        end   
        @moderator.is_super_mod?.must_equal false
        @moderator.update_attribute :lifecycle_segment, 5
        @moderator.is_super_mod?.must_equal true    
      end

      it 'segment between edger => super mod with enough posts' do
        55.times do |i|
          i < 1 ? @moderator.reload.moderator_segment.must_equal(nil) : @moderator.reload.moderator_segment.wont_be_nil
          i > 0 ? @moderator.is_edger_mod?.must_equal(true) : @moderator.is_edger_mod?.must_equal(false)
          i > 2 ? @moderator.is_noob_mod?.must_equal(true) : @moderator.is_noob_mod?.must_equal(false)
          i > 10 ? @moderator.is_regular_mod?.must_equal(true) : @moderator.is_regular_mod?.must_equal(false)
          i > 15 ? @moderator.is_advanced_mod?.must_equal(true) : @moderator.is_advanced_mod?.must_equal(false)
          i > 30 ? @moderator.is_super_mod?.must_equal(true) : @moderator.is_super_mod?.must_equal(false)

          post = create :post, 
            user: @user, 
            requires_action: true, 
            in_reply_to_post_id: @post_question.id,
            in_reply_to_user_id: @asker.id,
            in_reply_to_question_id: @question.id,
            interaction_type: 2, 
            conversation: @conversation
          moderation = create(:post_moderation, type_id:1, user_id: @moderator.id, post_id: post.id)
          moderation.update_attribute :accepted, true
          @moderator.update_attribute :lifecycle_segment, 5
        end 
      end 

      it 'segment between edger => super mod with enough acceptance' do
        100.times do 
          post = FactoryGirl.create :post, 
            user: @user, 
            requires_action: true, 
            in_reply_to_post_id: @post_question.id,
            in_reply_to_user_id: @asker.id,
            in_reply_to_question_id: @question.id,
            interaction_type: 2, 
            conversation: @conversation
          @user.segment

          FactoryGirl.create(:post_moderation, type_id:1, accepted: false, user_id: @moderator.id, post_id: post.id)
        end

        @moderator.update_attribute :lifecycle_segment, 5
        @moderator.post_moderations.each_with_index do |moderation, i|
          moderation.update_attribute :accepted, true
          @moderator.is_edger_mod?.must_equal(true)
          @moderator.is_noob_mod?.must_equal(true) if i > 49
          @moderator.is_regular_mod?.must_equal(true) if i > 64
          @moderator.is_advanced_mod?.must_equal(true) if i > 79
          @moderator.is_super_mod?.must_equal(true) if i > 89
        end
      end           
    end
  end
end

describe User, "#select_reengagement_asker" do
  let(:user) { create :user }
  let(:asker) { create :asker }
  let(:twitter_asker) { asker.becomes(TwitterAsker) }

  it "will return a followed asker if no responses yet" do
    asker.followers << user
    user.select_reengagement_asker.must_equal twitter_asker
  end

  it 'will return nil if no followed asker and no responded to asker' do
    user.select_reengagement_asker.must_equal nil
  end

  it 'will return a responded to asker if exists' do
    asker.followers << user
    create(:correct_response, 
      user: user,
      in_reply_to_user_id: asker.id)
    user.select_reengagement_asker.must_equal twitter_asker
  end

  it 'will return most responded to asker' do
    askers = []
    5.times do
      _asker = create :asker
      _asker.followers << user
      askers << _asker

      create(:correct_response, 
        user: user,
        in_reply_to_user_id: _asker.id)
    end

    most_popular = askers.sample.becomes TwitterAsker

    response_to_asker = create(:correct_response, 
      user: user,
      in_reply_to_user_id: most_popular.id)

    user.select_reengagement_asker.must_equal most_popular
  end
end