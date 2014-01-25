require 'test_helper'

describe Post, "EngagementEngine::Utils::Linker#link_to_question" do
  it "wont link DM to a question if none has been asked" do
    asker = create(:asker)
    question = create(:question)

    dm = create(:dm, text: 'true')

    dm.link_to_question

    dm.in_reply_to_question.must_be_nil
  end

  it "links a DM to a question for initial question dm" do
    asker = create(:asker)
    user = create(:user)
    question = create(:question)
    dm_question = create(:dm,
      question: question, 
      intention: 'initial question dm',
      user: asker,
      in_reply_to_user: user)

    conversation = create(:conversation, post: dm_question)
    dm_answer = create(:dm, 
      text: 'true', 
      conversation: conversation,
      user: user)
    dm_answer.link_to_question
    
    dm_answer.in_reply_to_question.must_equal question 
  end

  it "links mention response by amatch" do
    asker = create(:asker)
    user = create(:user)
    question = create(:question, 
      text: 'Is it true that this is nice?', 
      asker: asker)

    publication = create(:publication)
    post = create(:post, publication: publication)
    mention_answer = create(:post, 
      text: "@#{asker.twi_screen_name} true :) Is it true that this is nice?", 
      in_reply_to_user: asker,
      user: user,
      publication: publication)
    mention_answer.link_to_question
    
    mention_answer.in_reply_to_question.must_equal question 
  end
end