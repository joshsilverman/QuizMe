class QuestionsController < ApplicationController
  before_filter :authenticate_user!, :except => [:new, :refer, :show, :display_answers]
  before_filter :admin?, :only => [:index, :moderate, :moderate_update, :import, :enqueue, :dequeue, :manage]
  before_filter :author?, :only => [:enqueue, :dequeue]


  def index
    params[:asker_id] = nil if params[:asker_id] == '0'

    if current_user.is_role? 'admin'
      @questions = Question
    else
      @questions = current_user.questions
    end

    if params[:asker_id]
      @asker = Asker.find params[:asker_id]
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
    @question = Question.find(params[:id])
    @asker = User.find(@question.created_for_asker_id)
    publications = Publication.includes(:posts).where(:question_id => params[:id], :published => true).order("created_at DESC")
    @publication = publications.first
    
    if params[:slug].nil?
      redirect_to "/questions/#{params[:id]}/#{@question.slug}"
      return
    end
    is_follow_up = params[:lt] == "follow_up"
    @show_answer = true unless is_follow_up #!params[:ans].nil?

    publications.each { |pub| posts += pub.posts.collect(&:id) }
    @actions = {params[:id].to_i => []}
    user_ids = []
    Post.select([:user_id, :interaction_type, :in_reply_to_post_id, :created_at]).where(:in_reply_to_post_id => posts).order("created_at ASC").includes(:user).each do |action|
      next if user_ids.include? action.user_id 
      user = action.user
      user_ids << user.id
      @actions[params[:id].to_i]  << {
        :user => {
          :id => user.id,
          :twi_screen_name => user.twi_screen_name,
          :twi_profile_img_url => user.twi_profile_img_url
        },
        :interaction_type => action.interaction_type
      }
    end
    redirect_to "/feeds/#{@asker.id}" unless (@question and @publication)

    opts = ['no follow button or video', 'follow button and video']
    @new_question_page = ab_test("Better question pages (=> follow)", opts[0], opts[1]) == opts[1] ? true : false
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
    @question = Question.find(params[:id])
    @question.update inaccurate: nil, ungrammatical: nil
    params[:question][:status] = 0 unless current_user.is_role? 'admin' or current_user.is_role? 'asker' 
    # @question = current_user.questions.find(params[:id])
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
    return if params[:question].blank? or params[:canswer].blank?

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

      ## Trigger UGC events
      Post.trigger_split_test(user_id, 'ugc request type')
      Post.trigger_split_test(user_id, 'ugc script v4.0')
      if author.questions.size > 1
        Post.trigger_split_test(user_id, 'author followup type (return ugc submission)') 
        Post.trigger_split_test(user_id, "request immediate feedback on author's questions (return submission)") 
      end
      Post.trigger_split_test(user_id, 'ugc cta after five answers on site (adds question)')
      Post.trigger_split_test(user_id, 'new handle ugc request script v2 (=> add question)')
      Post.trigger_split_test(user_id, 'first ugc request type (writes a question)')

      Mixpanel.track_event "submitted question", {
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

  def manage
    all_questions = Question.where('status = 0').includes(:answers, :publications, :asker).order("questions.id DESC")
    @questions = all_questions.where('moderation_trigger_type_id is not null').page(params[:page]).per(25)
    @moderated_count = @questions.count
    @pending_count = all_questions.count - @questions.count
  end
end