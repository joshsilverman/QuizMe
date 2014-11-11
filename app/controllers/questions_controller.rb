class QuestionsController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => [:save_question_and_answers]
  before_filter :authenticate_user!, :except => [:refer, :show, :display_answers, :count]
  before_filter :admin?, :only => [:index, :moderate, :moderate_update, :enqueue, :dequeue, :manage]
  before_filter :author?, :only => [:enqueue, :dequeue]

  def show
    @publication = Publication.published
      .where(question_id: params[:id])
      .order(created_at: :desc).first

    if !@publication
      redirect_to '/'
      return
    end

    @publication.verify_cache_present

    @asker = Asker.find_by(id: @publication.asker_id)
    redirect_to '/' if !@asker

    respond_to do |format|
      format.html.phone do
        render :show, layout: 'phone'
      end

      format.html.none do
        url = "#{FEED_URL}/#{@asker.subject_url}/#{@publication.id}"
        redirect_to url, status: 301
      end

      format.json do
        redirect_to controller: :feeds,
          action: :show,
          format: :json,
          subject: @asker.subject_url,
          offset: params[:offset]
      end
    end
  end

  def update
    @question = Question.find(params[:id])
    @question.update inaccurate: nil, ungrammatical: nil
    params[:question][:status] = 0 unless current_user.is_role? 'admin' or current_user.is_role? 'asker'

    redirect_to "/" unless @question
    respond_to do |format|
      if @question.update_attributes(params[:question])
        format.json { head :ok }
      else
        format.json { render json: @question.errors, status: :unprocessable_entity }
      end
    end
  end

  def update_question_and_answers
    question = Question.includes(:answers).find(params[:question_id])
    question.update(text: params[:text], status: 0)
    question.clear_feedback
    question.question_moderations.each { |qm| qm.update(active: false) }
    params[:answers].each do |answer_params|
      if answer_params[1][:id].present?
        question.answers.find(answer_params[1][:id].to_i).update(text: answer_params[1][:text])
      else
        question.answers.create(text: answer_params[1][:text], correct: answer_params[1][:correct])
      end
    end
    render nothing: true, status: 200
  end

  # this method turned into a clusterf*ck because it combines update/create actions
  # #amateur-hour
  def save_question_and_answers
    if params[:question].blank? or params[:canswer].blank?
      head 400
      return
    end

    if params[:question_id] # updating question
      @question = Question.find params[:question_id]
      return if current_user.id != @question.user_id and !current_user.is_role? "admin"
      @question.text = params[:question]
      @question.priority = true
      @question.status = 1
      @question.save
    else # new question
      user_id = current_user.id
      question_created_at = nil
      asker_id = nil

      if params[:post_id] # For questions generated from user posts
        ugc_post = Post.find(params[:post_id])
        # ugc_post.tags.delete(Tag.find_by(name: "ugc"))
        user_id = ugc_post.user_id
        question_created_at = ugc_post.created_at
        asker_id = ugc_post.in_reply_to_user_id
      else
        asker_id = params[:asker_id]
      end
      asker = Asker.find(asker_id)

      @question = Question.create({
        :text => params[:question],
        :user_id => user_id,
        :priority => true,
        :created_for_asker_id => asker.id,
        :status => 0
      })

      author = @question.user

      MP.track_event "submitted question", {
        :distinct_id => user_id,
        :time => question_created_at ? question_created_at.to_i : @question.created_at.to_i,
        :type => params[:post_id].present? ? "post" : "form",
        :asker => asker.twi_screen_name,
        :lifecycle_segment => author.lifecycle_segment
      }
    end

    #correct answer save
    @answer = Answer.find_or_create_by(id: params[:canswer_id])
    @answer.update_attributes(:text => params[:canswer], :correct => true)
    @question.answers << @answer

    #other answers save
    [:ianswer1, :ianswer2, :ianswer3].each do |answer_key|
      if !params[answer_key].nil? and !params[answer_key].blank?
        @answer = nil
        @answer = @question.answers.find(params[answer_key.to_s + "_id"]) unless params[answer_key.to_s + "_id"].nil?
        if @answer
          @answer.update_attributes(:text => params[answer_key], :correct => false)
        else
          @answer = @question.answers.create :text => params[answer_key], :correct => false
          # @question.answers << @answer
        end
      elsif !params[answer_key.to_s + "_id"].nil?
        @question.answers.find(params[answer_key.to_s + "_id"]).destroy
      end
    end

    #update cache synchronously - will also be run async
    @question.update_answers

    current_user.update_user_interactions({
      :learner_level => "author",
      :last_interaction_at => @question.created_at
    })

    render :json => @question
  end

  def moderate
    @questions = Question.where(:status => 0)
  end

  def moderate_update
    question = Question.find(params[:question_id])
    question.update_attribute(:status, (params[:accepted].match(/(true|t|yes|y|1)$/i) != nil) ? 1 : -1)
    question.question_moderations.each { |qm| qm.update_attribute(:accepted, ((question.status == 1 and qm.type_id == 7) or (question.status == -1 and qm.type_id != 7))) }

    render :json => question.status, :status => 200
  end

  def count
    count = Question.where(user_id: params[:user_id]).count

    render json: count
  end
end
