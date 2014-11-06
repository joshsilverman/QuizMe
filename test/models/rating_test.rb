require 'test_helper'

describe Rating, 'valid?' do
  it "returns false without user_id" do
    rating = Rating.new
    rating.valid?.must_equal false
    rating.errors[:user_id].wont_be_empty
  end

  it "returns false without question_id" do
    rating = Rating.new
    rating.valid?.must_equal false
    rating.errors[:question_id].wont_be_empty
  end

  it "returns false without score" do
    rating = Rating.new
    rating.valid?.must_equal false
    rating.errors[:score].wont_be_empty
  end

  it "returns true with valid attrs" do
    rating = Rating.new user_id: 1, question_id: 1, score: 4
    rating.valid?.must_equal true
  end

  it "returns false if score not in range" do
    rating = Rating.new user_id: 1, question_id: 1, score: 6
    rating.valid?.must_equal false
    rating.errors[:score].wont_be_empty

    rating = Rating.new user_id: 1, question_id: 1, score: -1
    rating.valid?.must_equal false
    rating.errors[:score].wont_be_empty

    rating = Rating.new user_id: 1, question_id: 1, score: 3
    rating.valid?.must_equal true
    rating.errors[:score].must_be_empty
  end
end