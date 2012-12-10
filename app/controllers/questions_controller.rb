class QuestionsController < ApplicationController
  before_filter :authenticate_user, :except => [:new, :refer, :show, :display_answers]
  before_filter :admin?, :only => [:moderate, :moderate_update, :import, :enqueue, :dequeue]
  before_filter :author?, :only => [:index, :enqueue, :dequeue]


  def index
    params[:asker_id] = nil if params[:asker_id] == '0'

    if current_user.is_role? 'admin'
      @questions = Question
    else
      @questions = current_user.questions
    end

    if params[:asker_id]
      @questions = @questions.where(:created_for_asker_id => params[:asker_id])
    else
      @questions = @questions
    end

    @all_questions = @questions.includes(:answers, :publications, :asker).order("questions.id DESC")
    @questions_enqueued = @questions.includes(:answers, :publications, :asker).joins(:publications, :asker).where("publications.publication_queue_id IS NOT NULL").order("questions.id ASC")
    @questions = @questions.includes(:answers, :publications, :asker).where("publications.publication_queue_id IS NULL").order("questions.id DESC").page(params[:page]).per(25)

    @questions_hash = Hash[@all_questions.collect{|q| [q.id, q]}]
    @handle_data = User.askers.collect{|h| [h.twi_screen_name, h.id]}
    @approved_count = @all_questions.where(:status => 1).count
    @pending_count = @all_questions.where(:status => 0).count
  end

  def show(posts = [])
    @show_answer = !params[:ans].nil?
    @question = Question.find(params[:id])
    @asker = User.find(@question.created_for_asker_id)
    publications = Publication.includes(:posts).where(:question_id => params[:id], :published => true).order("created_at DESC")
    @publication = publications.first
    publications.each { |pub| posts += pub.posts.collect(&:id) }
    @actions = {params[:id].to_i => []}
    Post.select([:user_id, :interaction_type, :in_reply_to_post_id, :created_at]).where(:in_reply_to_post_id => posts).order("created_at ASC").includes(:user).each do |action|
      @actions[params[:id].to_i]  << {
        :user => {
          :id => action.user.id,
          :twi_screen_name => action.user.twi_screen_name,
          :twi_profile_img_url => action.user.twi_profile_img_url
        },
        :interaction_type => action.interaction_type
      }
    end
    redirect_to "/feeds/#{@asker.id}" unless (@question and @publication and @question.slug == params[:slug])
  end

  def new
    @asker = User.asker(params[:asker_id])
    topic = @asker.topics.first
    @topic_tag = topic.id if topic
    @asker_id = @asker.id
    @question = Question.new
    @success = params[:success] if params[:success]

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @question }
    end
  end

  def edit
    @question = current_user.questions.find(params[:id])
    redirect_to "/" unless @question
  end

  def create
    @question = Question.new(params[:question])

    respond_to do |format|
      if @question.save
        format.html { redirect_to @question, notice: 'Question was successfully created.' }
        format.json { render json: @question, status: :created, location: @question }
      else
        format.html { render action: "new" }
        format.json { render json: @question.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @question = current_user.questions.find(params[:id])
    redirect_to "/" unless @question

    respond_to do |format|
      if @question.update_attributes(params[:question])
        format.html { redirect_to @question, notice: 'Question was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @question.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @question = current_user.questions.find(params[:id])
    redirect_to "/" unless @question
    @question.destroy

    respond_to do |format|
      format.html { redirect_to questions_url }
      format.json { head :ok }
    end
  end

  # this method turned into a clusterf*ck because it combines update/create actions
  # @amateur-hour
  def save_question_and_answers
    return if params[:question].blank? or params[:canswer].blank?

    if params[:question_id]
      @question = Question.find params[:question_id]
      return if current_user.id != @question.user_id
    end
    @question ||= Question.new

    @question.text = params[:question]
    @question.user_id = current_user.id
    @question.priority = true
    @question.created_for_asker_id = params[:asker_id]
    @question.status = 0
    @question.save

    #correct answer save
    @answer = Answer.find_or_create_by_id(params[:canswer_id])
    @answer.update_attributes(:text => params[:canswer], :correct => true)
    @question.answers << @answer

    #other answers save
    [:ianswer1, :ianswer2, :ianswer3].each do |answer_key|
      if !params[answer_key].nil? and !params[answer_key].blank?
        @answer = nil
        @answer = Answer.find(params[answer_key.to_s + "_id"]) unless params[answer_key.to_s + "_id"].nil?
        puts @answer.nil?
        if @answer
          @answer.update_attributes(:text => params[answer_key], :correct => false)
        else
          @answer = Answer.create :text => params[answer_key], :correct => false
          @question.answers << @answer
        end
      elsif !params[answer_key.to_s + "_id"].nil?
        Answer.find(params[answer_key.to_s + "_id"]).destroy
      end
    end

    render :json => @question
  end

  def moderate
    @questions = Question.where(:status => 0)    
  end

  def moderate_update
    question = Question.find(params[:question_id])
    accepted = params[:accepted].match(/(true|t|yes|y|1)$/i) != nil
    if accepted
      question.update_attributes(:status => 1)
      a = User.asker(question.created_for_asker_id)
      # Post.dm(a, "Your question was accepted! Nice!", nil, nil, question.id, question.user.twi_user_id)
    else
      question.update_attributes(:status => -1)
      a = User.asker(question.created_for_asker_id)
      ## DM user to let them know!
      # Post.dm(a, "Your question was not approved. Sorry :(", nil, nil, question.id, question.user.twi_user_id)
    end
    render :nothing => true, :status => 200
  end

  def export
    @questions = Question.all
    respond_to :json
  end

  def enqueue
    PublicationQueue.enqueue_question params[:asker_id], params[:question_id]
    redirect_to "/questions/asker/#{params[:asker_id]}"
  end

  def dequeue
    PublicationQueue.dequeue_question params[:asker_id], params[:question_id]
    redirect_to "/questions/asker/#{params[:asker_id]}"
  end

  def display_answers
    @question = Question.includes(:answers).find(params[:question_id])
    render :partial => "answers"
  end

  def import
    return unless params[:questions]

    @asker = Asker.find params[:asker_id]
    questions = params[:questions].split "\n"
    questions.each do |q|
      q_matchdata = /(.*)\s+(\([^\)]*\))/.match q

      q_text = q_matchdata[1]
      q_ans = q_matchdata[2]

      as = q_ans.gsub(/^\(|\)$/, '').split /\sor\s|,\s/
      randomized_answers = as.shuffle
      last_answer = randomized_answers.pop
      answer_string = randomized_answers.join(", ") + " or #{last_answer}"
      correct_ans = as.shift

      if params[:hide_answers] != 'on'
        q_text = "#{q_text} (#{answer_string})"
      end

      @question = Question.find_by_text q_text
      #next if @question

      @question = @asker.questions.create :text => q_text, :user_id => current_user.id
      @question.answers.create :text => correct_ans, :correct => true
      as.each{|a| @question.answers.create :text => a, :correct => false}
    end

    render :text => questions.to_yaml
  end
end
