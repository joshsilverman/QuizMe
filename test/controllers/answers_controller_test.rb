require 'test_helper'

describe AnswersController, '#update' do
  let (:author) { create(:user, twi_user_id: 1, role: 'user') }
  let (:admin) { create(:admin) }
  let (:hacker) { create(:user) }

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

  it 'updates answer when edited with nested style' do
    sign_in author
    question.update!(bad_answers: true)
    put :update, id: answer.id, answer: {text: "Star Wars I"}, format: :json

    answer.reload.text.must_equal "Star Wars I"
  end

  it 'updates answer when edited with non-nested style' do
    sign_in author
    question.update!(bad_answers: true)
    put :update, id: answer.id, text: "Star Wars I", format: :json

    answer.reload.text.must_equal "Star Wars I"
  end

  it 'allows admin to edit another person question' do
    sign_in admin
    question.update!(bad_answers: true)
    put :update, id: answer.id, text: "Star Wars I", format: :json

    answer.reload.text.must_equal "Star Wars I"
  end

  it 'wont allow non-admin/non-author to edit' do
    sign_in hacker
    question.update!(bad_answers: true)
    put :update, id: answer.id, text: "Star Wars I", format: :json

    response.status.must_equal 401
    answer.reload.text.wont_equal "Star Wars I"
  end

  it 'returns 401 if not authenticated' do
    question.update!(bad_answers: true)
    put :update, id: answer.id, text: "Star Wars I", format: :json

    response.status.must_equal 401
    answer.reload.text.wont_equal "Star Wars I"
  end

  it 'responds with answer' do
    sign_in author
    question.update!(bad_answers: true)
    put :update, id: answer.id, answer: {text: "yoyos"}, format: :json

    question.reload.bad_answers.must_equal nil
    JSON.parse(response.body)['id'].to_i.must_equal answer.id
  end
end