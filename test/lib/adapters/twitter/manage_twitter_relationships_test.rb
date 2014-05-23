require 'test_helper'

describe Asker, 'ManageTwitterRelationships' do

  before :each do
    @asker = create(:asker)
    @user = create(:user, twi_user_id: 1)

    @asker.followers << @user
    @asker.follower_relationships.update_all(channel: Relationship::TWITTER) 

    @question = create(:question, created_for_asker_id: @asker.id, status: 1)   
    @publication = create(:publication, question_id: @question.id)
    @question_status = create(:post, user_id: @asker.id, interaction_type: 1, question_id: @question.id, publication_id: @publication.id)   
    Delayed::Worker.delay_jobs = false

    @new_user = create(:user, twi_user_id: 2)
  end

  describe "autofollow" do
    it "sends follows five days a week and during 18 hour periods" do
      Timecop.travel(Time.now.beginning_of_week)
      sent = 0
      7.times do |i|
        24.times do |j|
          sent += 1 if @asker.autofollow_count > 0
          Timecop.travel(Time.now + 1.hour)
        end
      end
      sent.must_equal 5 * 18
    end

    it "obeys maximum daily follow limit on small handles" do
      Timecop.travel(Time.now.beginning_of_week)
      @asker.stub :followers, 1..150 do
        total_follows = []
        7.times do |i|
          follows_today = 0
          24.times do |j|
            Timecop.travel(Time.now + 1.hour)
            next if follows_today > 0
            follows_today = @asker.autofollow_count
          end
          total_follows << follows_today
        end
        total_follows.sum.must_equal 14
      end
    end

    it "obeys maximum daily follow limit on large handles" do
      Timecop.travel(Time.now.beginning_of_week)
      @asker.stub :followers, 1..10000 do
        total_follows = []
        7.times do |i|
          follows_today = 0
          24.times do |j|
            Timecop.travel(Time.now + 1.hour)
            next if follows_today > 0
            follows_today = @asker.autofollow_count
          end
          total_follows << follows_today
        end
        total_follows.sum.must_equal 36
      end
    end     

    it "obeys maximum daily unfollow limit on large handles" do
      100.times { @asker.follows << create(:user) }
      Timecop.travel(Time.now.beginning_of_week)
      @asker.stub :followers, 1..10000 do
        total_unfollows = []
        7.times do |i|
          unfollows_today = 0
          24.times do |j|
            Timecop.travel(Time.now + 1.hour)
            next if unfollows_today > 0
            unfollows_today = @asker.unfollow_count
          end
          total_unfollows << unfollows_today
        end
        total_unfollows.sum.must_equal 49
      end       
    end     

    it "follows proper number of users per day and week" do
      Timecop.travel(Time.now.beginning_of_week)
      @asker.stub :followers, 1..10000 do
        total_follows = []
        7.times do |i|
          follows_today = 0
          24.times do |j|
            Timecop.travel(Time.now + 1.hour)
            next if follows_today > 0
            follows_today = @asker.autofollow_count
          end
          total_follows << follows_today
        end
        total_follows.select { |f| f == 0 }.count.must_equal 2
        total_follows.select { |f| f < 16 }.count.must_equal 7
      end
    end   

    it "doesn't include followbacks in max follows per day" do
      @asker.follows.count.must_equal 0
      twi_user_ids = (5..10).to_a
      
      Post.stubs(:twitter_request).returns([1])

      @asker.followback(@asker.followers.collect(&:twi_user_id))
      @asker.reload.follows.count.must_equal 1
      @asker.send_autofollows(twi_user_ids, 5, { force: true })
      @asker.reload.follows.count.must_equal 6
    end

    it "sets correct twitter channel for followbacks" do
      @asker.follows.count.must_equal 0
      twi_user_ids = (5..10).to_a
      
      Post.stubs(:twitter_request).returns([1])

      @asker.followback(@asker.followers.collect(&:twi_user_id))
      @asker.reload.follows.count.must_equal 1
      @asker.follow_relationships.count.must_equal 1
      @asker.follow_relationships.twitter.count.must_equal 1
    end

    it "sets correct twitter channel for autofollows" do
      @asker.follows.count.must_equal 0
      twi_user_ids = (5..10).to_a
      
      Post.stubs(:twitter_request).returns([1])

      @asker.send_autofollows(twi_user_ids, 5, { force: true })
      @asker.reload.follows.count.must_equal 5
      @asker.follow_relationships.twitter.count.must_equal 5
    end

    it 'takes into account previous follows from today when calculating autofollow count' do
      autofollow_count = 0
      while autofollow_count < 2
        Timecop.travel(Time.now + 1.hour)
        autofollow_count = @asker.autofollow_count
      end
      @asker.autofollow_count.must_equal(autofollow_count)
      @asker.add_follow(create(:user), 2)
      @asker.reload.autofollow_count.must_equal(autofollow_count - 1)
    end

    it 'only looks at twitter follows' do
      autofollow_count = 0
      while autofollow_count < 2
        Timecop.travel(Time.now + 1.hour)
        autofollow_count = @asker.autofollow_count
      end
      
      @asker.autofollow_count.must_equal 2
      @asker.add_follow(create(:user), 2, Relationship::WISR)
      @asker.reload.autofollow_count.must_equal 2

      @asker.add_follow(create(:user), 2)
      @asker.reload.autofollow_count.must_equal 1
    end
  end

  describe "updates followers" do
    it "adds new follower" do
      @asker.followers.count.must_equal 1
      twi_follower_ids = [@user.twi_user_id, @new_user.twi_user_id]
      wisr_follower_ids = @asker.followers.collect(&:twi_user_id)
      @asker.update_followers(twi_follower_ids, wisr_follower_ids)
      @asker.reload.followers.count.must_equal 2
      @asker.follower_relationships.count.must_equal 2
      @asker.follower_relationships.twitter.count.must_equal 2
    end

    it "follows new follower back" do
      @asker.follows.must_be_empty
      twi_follower_ids = [@new_user.twi_user_id]
      wisr_follower_ids = @asker.followers.collect(&:twi_user_id)
      twi_follower_ids = @asker.update_followers(twi_follower_ids, wisr_follower_ids)
      @asker.follow_relationships.twitter.count.must_equal 0

      Post.stubs(:twitter_request).returns([1])

      @asker.followback(twi_follower_ids)
      @asker.reload.follows.must_include @new_user
      @asker.follow_relationships.reload.twitter.count.must_equal 1
    end

    it "sets correct type_id for user followback" do
      @asker.follows.must_be_empty
      twi_follower_ids = [@user.twi_user_id]
      wisr_follower_ids = @asker.followers.collect(&:twi_user_id)
      twi_follower_ids = @asker
        .update_followers(twi_follower_ids, wisr_follower_ids)

      Post.stubs(:twitter_request).returns([:not_empty])

      @asker.followback(twi_follower_ids)
      @asker.reload.follow_relationships.where("followed_id = ?", @user.id)
        .first.type_id.must_equal 1
    end

    it 'follows new follower back with pending requests' do
      @pending_user = create(:user, twi_user_id: 3)
      relationship = @asker.follow_relationships.find_or_create_by(followed_id: @pending_user.id)
      relationship.update_attribute :pending, true

      twi_follower_ids = [@pending_user.twi_user_id, @new_user.twi_user_id]
      wisr_follower_ids = @asker.followers.collect(&:twi_user_id)
      twi_follower_ids = @asker.update_followers(twi_follower_ids, wisr_follower_ids)

      Post.stubs(:twitter_request).returns([1])

      @asker.followback(twi_follower_ids)
      @asker.reload.follows.must_include @new_user        
    end

    it 'updates converted pending users to not pending' do
      @pending_user = create(:user, twi_user_id: 3)
      relationship = @asker.follow_relationships.find_or_create_by(followed_id: @pending_user.id)
      relationship.update_attribute :pending, true

      relationship.reload.pending.must_equal true
      relationship.reload.active.must_equal true

      twi_follows_ids = [@pending_user.twi_user_id]
      wisr_follows_ids = @asker.followers.collect(&:twi_user_id)
      @asker.update_follows(twi_follows_ids, wisr_follows_ids)

      relationship.reload.pending.must_equal false
      relationship.reload.active.must_equal true
    end

    it "removes unfollowers" do
      twi_follower_ids = []
      wisr_follower_ids = @asker.followers.collect(&:twi_user_id)       
      @asker.update_followers(twi_follower_ids, wisr_follower_ids)
      @asker = @asker.reload
      @asker.followers.count.must_equal 0
      @asker.follower_relationships.count.must_equal 1
    end
  end

  describe "updates follows" do
    it "adds new follows" do
      @asker.follows.count.must_equal 0
      twi_follows_ids = [@user.twi_user_id, @new_user.twi_user_id]
      wisr_follows_ids = @asker.follows.collect(&:twi_user_id)
      @asker.update_follows(twi_follows_ids, wisr_follows_ids)
      @asker.reload.follows.count.must_equal 2        
    end

    it "removes unfollows (regardless of channel)" do
      @asker.follows << @new_user
      twi_follows_ids = []
      wisr_follows_ids = @asker.follows.collect(&:twi_user_id)        
      @asker.update_follows(twi_follows_ids, wisr_follows_ids)
      @asker = @asker.reload
      @asker.follows.count.must_equal 0
      @asker.follow_relationships.count.must_equal 1
    end

    it "sets correct type_id for asker followback" do
      twi_follows_ids = [@user.twi_user_id, @new_user.twi_user_id]
      wisr_follows_ids = @asker.follows.collect(&:twi_user_id)
      @asker.update_follows(twi_follows_ids, wisr_follows_ids)
      @asker = @asker.reload
      @asker.follow_relationships.where("followed_id = ?", @new_user.id).first.type_id.must_be_nil
    end

    it "unfollows non-reciprocal follows after one month" do
      @asker.follows << @new_user
      twi_follows_ids = [@new_user.twi_user_id]

      Post.stubs(:twitter_request).returns([:not_empty])

      34.times do |i|
        Timecop.travel(Time.now + 1.day)
        @asker.unfollow_nonreciprocal(twi_follows_ids, 10)
        if i < 29
          @asker.reload.follows.count.must_equal 1
        else
          @asker.reload.follows.count.must_equal 0
        end
      end
    end

    it "unfollows non-reciprocal pending follows after one month" do
      @asker.follows.must_be_empty
      relationship = @asker.follow_relationships.find_or_create_by(followed_id: @new_user.id)
      relationship.update_attribute :pending, true
      twi_follows_ids = [@new_user.twi_user_id]

      Post.stubs(:twitter_request).returns([:not_empty])

      31.times do |i|
        Timecop.travel(Time.now + 1.day)
        @asker.unfollow_nonreciprocal(twi_follows_ids, 10)
        if i < 29
          @asker.reload.follows.count.must_equal 1
        else
          @asker.reload.follows.count.must_equal 0
        end
      end
    end

    it "does not unfollow reciprocal follow after one month" do
      @asker.follows << @new_user
      @new_user.follows << @asker
      twi_follows_ids = [@new_user.twi_user_id]
      32.times do |i|
        Timecop.travel(Time.now + 1.day)
        @asker.unfollow_nonreciprocal(twi_follows_ids, 10)
        @asker.reload.follows.count.must_equal 1
      end
    end

    it "doesn't followback inactive unfollows" do
      @inactive_user1 = create(:user, twi_user_id: 3)
      @asker.follows << @inactive_user1
      @asker.unfollow_oldest_inactive_user
      @asker.follows.count.must_equal 1

      Timecop.travel(Time.now + 91.days)
      @asker.reload.unfollow_oldest_inactive_user
      @asker.reload.followback [@inactive_user1.twi_user_id]
      @asker.reload.follows.count.must_equal 0
    end

    it "sets unfollows to inactive" do
      @asker.follows << @new_user
      @asker.follow_relationships.active.count.must_equal 1
      twi_follows_ids = [@new_user.twi_user_id]
      Timecop.travel(Time.now + 32.days)
      rel_count = @asker.reload.follow_relationships.count

      Post.stubs(:twitter_request).returns([:not_empty])

      @asker.unfollow_nonreciprocal(twi_follows_ids, 10)
      @asker.reload.follow_relationships.active.count.must_equal 0
      @asker.reload.follow_relationships.count.must_equal rel_count
    end
  end   

  it 'links users to search terms they were followed through' do
    search_term = create(:search_term)
    @new_user.reload.search_term_topic_id.must_equal nil
    twi_user_ids = [@new_user.twi_user_id]
    @asker.send_autofollows(twi_user_ids, 5, { force: true, search_term_source: { @new_user.twi_user_id => search_term } })
    @new_user.reload.search_term_topic_id.must_equal search_term.id
  end
end

describe Asker, 'ManageTwitterRelationships#send_targeted_mention' do
  it 'sends targeted mention post' do
    asker = create :asker
    user = create :user

    question = create :question
    publication = create :publication, asker: asker, question: question
    asker.stubs(:most_popular_question).returns(question)

    asker.send_targeted_mention user

    Post.count.must_equal 1
    Post.first.intention.must_equal 'targeted mention'
  end

  it 'with correct url' do
    asker = create :asker
    user = create :user

    question = create :question
    publication = create :publication, asker: asker, question: question
    asker.stubs(:most_popular_question).returns(question)

    asker.send_targeted_mention user

    uri = URI.parse Post.first.url
    uri.path.must_equal "/#{asker.subject_url}/#{publication.id}"
  end
end

describe Asker, 'ManageTwitterRelationships#followback' do
  before :each do
    @asker = create(:asker)
    @user = create(:user, twi_user_id: 1)

    @asker.followers << @user   

    @question = create(:question, created_for_asker_id: @asker.id, status: 1)   
    @publication = create(:publication, question_id: @question.id)
    @question_status = create(:post, user_id: @asker.id, interaction_type: 1, question_id: @question.id, publication_id: @publication.id)   
    Delayed::Worker.delay_jobs = false

    @new_user = create(:user, twi_user_id: 2)
  end

  it 'wont call add_follow if follow request returns empty' do
    @asker.follows.must_be_empty
    twi_follower_ids = [@new_user.twi_user_id]
    wisr_follower_ids = @asker.followers.collect(&:twi_user_id)
    twi_follower_ids = @asker.update_followers(twi_follower_ids, wisr_follower_ids)

    Post.stubs(:twitter_request).returns([])

    @asker.expects(:add_follow).never

    @asker.followback(twi_follower_ids)
    @asker.reload.follows.wont_include @new_user
  end

  it 'sets asker.last_followback_failure to datetime' do
    @asker.follows.must_be_empty
    twi_follower_ids = [@new_user.twi_user_id]
    wisr_follower_ids = @asker.followers.collect(&:twi_user_id)
    twi_follower_ids = @asker.update_followers(twi_follower_ids, wisr_follower_ids)

    Post.stubs(:twitter_request).returns([])
    Timecop.freeze(Time.now)
    @asker.followback(twi_follower_ids)

    @asker.reload.last_followback_failure.to_i.must_equal Time.now.to_i
  end

  it 'wont set asker.last_followback_failure if follow succeeds' do
    @asker.follows.must_be_empty
    twi_follower_ids = [@new_user.twi_user_id]
    wisr_follower_ids = @asker.followers.collect(&:twi_user_id)
    twi_follower_ids = @asker.update_followers(twi_follower_ids, wisr_follower_ids)

    Post.stubs(:twitter_request).returns([:not_empty])
    Timecop.freeze(Time.now)
    @asker.followback(twi_follower_ids)

    @asker.reload.last_followback_failure.must_equal nil
  end
end