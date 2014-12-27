require 'test_helper'

describe Asker, "#reengage_inactive_users" do
  before :each do
    @asker = create(:asker)
    @user = create(:user, twi_user_id: 1)
    @strategy = [1, 2, 4, 8]

    @asker.followers << @user

    @question = create(:question, created_for_asker_id: @asker.id, status: 1)
    @old_question = create(:question, created_for_asker_id: @asker.id, status: 1)
    @publication = create(:publication, question_id: @question.id)
    @question_status = create(:post, user_id: @asker.id, interaction_type: 1, question_id: @question.id, publication_id: @publication.id)
    Delayed::Worker.delay_jobs = false
  end

  describe "for twitter users" do
    it "reengages users who answered a question via mention" do
      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).must_be_empty

      create(:post, text: 'the correct answer, yo',
        user: @user,
        in_reply_to_user_id: @asker.id,
        interaction_type: 2,
        in_reply_to_question_id: @old_question.id,
        correct: true)

      Timecop.travel(Time.now + 1.day)

      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).wont_be_empty
    end

    it "reengages user who answered a question via mention with a mention" do
      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).must_be_empty
      @user.update lifecycle_segment: 2

      create(:post, text: 'the correct answer, yo',
        user: @user,
        in_reply_to_user_id: @asker.id,
        interaction_type: 2,
        in_reply_to_question_id: @old_question.id,
        correct: true)

      Timecop.travel(Time.now + 1.day)

      Asker.reengage_inactive_users strategy: @strategy
      reengagement = Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).first

      reengagement.interaction_type.must_equal 2
    end

    it "reengages user who answered a question via dm" do
      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).must_be_empty

      create(:post, text: 'the correct answer, yo',
        user: @user,
        in_reply_to_user_id: @asker.id,
        interaction_type: 4,
        in_reply_to_question_id: @old_question.id,
        correct: true)

      Timecop.travel(Time.now + 1.day)

      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).wont_be_empty
    end

    it "reengages users who answered a question via dm with a dm" do
      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).must_be_empty
      @user.update lifecycle_segment: 1

      create(:post, text: 'the correct answer, yo',
        user: @user,
        in_reply_to_user_id: @asker.id,
        interaction_type: 4,
        in_reply_to_question_id: @old_question.id,
        correct: true)

      Timecop.travel(Time.now + 1.day)

      Asker.reengage_inactive_users strategy: @strategy
            reengagement = Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).first

      reengagement.interaction_type.must_equal 4
    end

    it "wont overengage if a user suddenly enters reengagement flow" do
      Asker.reengage_inactive_users strategy: [1,2,4,8]
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).must_be_empty

      create(:post, text: 'the correct answer, yo',
        user: @user,
        in_reply_to_user_id: @asker.id,
        interaction_type: 4,
        in_reply_to_question_id: @old_question.id,
        correct: true)

      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).count.must_equal 0

      10.times do
        Timecop.travel(Time.now + 3.day)
        Asker.reengage_inactive_users strategy: @strategy
      end

      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).count.must_be :<=, 3
    end

    it "reengages user who have moderated a post" do
      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(user_id: @asker.id, in_reply_to_user_id: @user.id).must_be_empty

      create(:post_moderation, user_id: @user.id, type_id: 1, post: create(:post))
      Timecop.travel(Time.now + 1.day)

      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(user_id: @asker.id, in_reply_to_user_id: @user.id).wont_be_empty
    end

    it "reengages user who have written a question" do
      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(user_id: @asker.id, in_reply_to_user_id: @user.id).must_be_empty

      create(:question, user_id: @user.id, created_for_asker_id: @asker.id)
      Timecop.travel(Time.now + 1.day)

      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(user_id: @asker.id, in_reply_to_user_id: @user.id).wont_be_empty
    end

    it "reengages users who have gone inactive" do
      create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @old_question.id, correct: true)
      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).must_be_empty

      Timecop.travel(Time.now + 1.day)
      create(:post_moderation, user_id: @user.id, type_id: 1, post: create(:post))
      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).must_be_empty

      Timecop.travel(Time.now + 1.day)
      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).wont_be_empty
    end

    it "wont reengage if user has been deleted" do
      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).must_be_empty

      create(:post, text: 'the correct answer, yo',
        user_id: 123456,
        in_reply_to_user_id: @asker.id,
        interaction_type: 2,
        in_reply_to_question_id: @old_question.id,
        correct: true)

      Timecop.travel(Time.now + 1.day)

      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => @user.id).must_be_empty
    end
  end

  describe "iphoners" do
    let(:iphoner) {
      iphoner = create :iphoner
      @asker.followers << iphoner
      iphoner
    }

    it "reengages iphoner with device token" do
      iphoner

      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => iphoner.id).must_be_empty

      create(:post, text: 'the correct answer, yo',
        user: iphoner,
        in_reply_to_user_id: @asker.id,
        interaction_type: 2,
        in_reply_to_question_id: @old_question.id,
        correct: true)

      Timecop.travel(Time.now + 1.day)

      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => iphoner.id).wont_be_empty
    end

    it "wont reengage iphoner with no device token" do
      iphoner.update device_token: nil

      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => iphoner.id).must_be_empty

      create(:post, text: 'the correct answer, yo',
        user: iphoner,
        in_reply_to_user_id: @asker.id,
        interaction_type: 2,
        in_reply_to_question_id: @old_question.id,
        correct: true)

      Timecop.travel(Time.now + 1.day)

      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id,
        :in_reply_to_user_id => iphoner.id).must_be_empty
    end
  end

  describe "who are qualified" do
    before :each do
      @strategy = [1, 2, 4, 8]

      @user_response = create(:post, text: 'the correct answer, yo', user_id: @user.id, in_reply_to_user_id: @asker.id, interaction_type: 2, in_reply_to_question_id: @old_question.id)
      @user_response.update_attribute :correct, true
      @user.update_attributes last_answer_at: @user_response.created_at, last_interaction_at: @user_response.created_at, activity_segment: nil

      create(:post, in_reply_to_user_id: @asker.id, correct: true, interaction_type: 2, in_reply_to_question_id: @question.id)
    end

    it "with a post" do
      Timecop.travel(Time.now + 1.day)
      Asker.reengage_inactive_users strategy: @strategy

      Post.reengage_inactive
        .where(:user_id => @asker.id, :in_reply_to_user_id => @user.id)
        .wont_be_empty
    end

    it "with correct link" do
      Timecop.travel(Time.now + 1.day)
      Asker.reengage_inactive_users strategy: @strategy

      post = Post.reengage_inactive
        .where(:user_id => @asker.id, :in_reply_to_user_id => @user.id)
        .last

      uri = URI.parse post.url
      path = uri.path

      path.must_equal "/#{@asker.subject_url}/#{@publication.id}"
    end

    it "on the proper schedule" do
      intervals = []
      @strategy.each_with_index { |e, i| intervals << @strategy[0..i].sum }
      (@strategy.sum + 1).times do |i|
        Asker.reengage_inactive_users strategy: @strategy
        Post.reengage_inactive.where("user_id = ? and in_reply_to_user_id = ? and created_at > ?", @asker.id, @user.id, Time.now.beginning_of_day).present? if intervals.include? i
        Timecop.travel(Time.now + 1.day)
      end
    end

    it "from an asker that they are following" do
      Timecop.travel(Time.now + 1.day)
      @asker.followers.delete @user
      Asker.reengage_inactive_users strategy: @strategy
      Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).must_be_empty
    end

    it "unless they've already been reengaged" do
      Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).count.must_equal 0
      Timecop.travel(Time.now + 1.day)
      2.times do
        Asker.reengage_inactive_users strategy: @strategy
        Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id).count.must_equal 1
      end
    end

    it 'with a question' do
      Timecop.travel(Time.now + 1.day)
      Asker.reengage_inactive_users strategy: @strategy, type: :question
      posts = Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id)
      posts.count.must_equal 1
      post = posts.first
      post.question_id.wont_be_nil and post.intention.must_equal 'reengage inactive'
    end

    it 'unless max reengagements hit' do
      Asker.stubs(:max_hourly_reengagements).returns(0)

      Timecop.travel(Time.now + 1.day)
      Asker.reengage_inactive_users strategy: @strategy, type: :question
      posts = Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id)

      posts.count.must_equal 0
    end

    it 'with a moderation request' do
      Timecop.travel(Time.now + 1.day)
      Asker.reengage_inactive_users strategy: @strategy, type: :moderation
      posts = Post.reengage_inactive.where(:user_id => @asker.id, :in_reply_to_user_id => @user.id)
      posts.count.must_equal 1
      post = posts.first
      post.question_id.must_be_nil and post.intention.must_equal 'request mod'
    end

    it 'with nothing - raise runtime error' do
      Timecop.travel(Time.now + 1.day)
      -> { Asker.reengage_inactive_users strategy: @strategy, type: :author }.must_raise RuntimeError
    end

    describe "with a question" do
      it "that has been approved" do
        Timecop.travel(Time.now + 1.day)
        @unapproved_question = create(:question, created_for_asker_id: @asker.id, status: 0)
        Asker.reengage_inactive_users strategy: @strategy
        Post.reengage_inactive
          .where(:user_id => @asker.id, :in_reply_to_user_id => @user.id)
          .first.question.status.must_equal 1
      end
    end
  end
end
