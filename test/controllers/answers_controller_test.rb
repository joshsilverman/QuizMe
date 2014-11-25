require 'test_helper'

describe AnswersController, '#update' do
  let (:author) { create(:user, twi_user_id: 1, role: 'user') }

  let (:asker) { 
    a = create(:asker) 
    a.followers << author
    a
  }

  let (:question) { create(:question, created_for_asker_id: asker.id, status: -1, user: author, inaccurate: true, ungrammatical: true, bad_answers: true) }
  let (:answer) { question.answers.first }

  it 'clears answer feedback when answers edited' do
    sign_in author
    question.update!(bad_answers: true)
    put :update, id: answer.id, answer: {text: "yoyos"}, format: :json

    question.reload.bad_answers.must_equal nil
  end
end