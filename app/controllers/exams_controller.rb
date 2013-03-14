class ExamsController < ApplicationController
	before_filter :admin?

  def create
  	params['exam']['price'] = params['exam']['price'].to_f
  	params['exam']['question_count'] = params['exam']['question_count'].to_i

  	puts params['exam']

    if Exam.create params['exam']

    	render text: nil, status: 200
    else
    	render text: nil, status: 400
    end
  end
end