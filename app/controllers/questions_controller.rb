class QuestionsController < ApplicationController
  before_filter :authenticate_user!, :except => [:new, :refer, :show, :display_answers]
  before_filter :admin?, :only => [:moderate, :moderate_update, :import, :enqueue, :dequeue]
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
    @show_answer = !params[:ans].nil?
    @question = Question.find(params[:id])
    @asker = User.find(@question.created_for_asker_id)
    publications = Publication.includes(:posts).where(:question_id => params[:id], :published => true).order("created_at DESC")
    @publication = publications.first
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
    @question = Question.find(params[:id])
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

  # this method turned into a clusterf*ck because it combines update/create actions
  # @amateur-hour
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
        # ugc_post.tags.delete(Tag.find_by_name("ugc"))
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
      Post.trigger_split_test(user_id, 'author followup type (return ugc submission)') if author.questions.size > 1
      Post.trigger_split_test(user_id, 'ugc cta after five answers on site (adds question)')
      Post.trigger_split_test(user_id, 'new handle ugc request script (=> add question)')

      Mixpanel.track_event "submitted question", {
        :distinct_id => user_id,
        :time => question_created_at ? question_created_at.to_i : @question.created_at.to_i,
        :type => params[:post_id].present? ? "post" : "form",
        :asker => asker.twi_screen_name,
        :lifecycle_segment => author.lifecycle_segment
      }
    end

    #correct answer save
    @answer = Answer.find_or_create_by_id(params[:canswer_id])
    @answer.update_attributes(:text => params[:canswer], :correct => true)
    @question.answers << @answer

    #other answers save
    [:ianswer1, :ianswer2, :ianswer3].each do |answer_key|
      if !params[answer_key].nil? and !params[answer_key].blank?
        @answer = nil
        @answer = Answer.find(params[answer_key.to_s + "_id"]) unless params[answer_key.to_s + "_id"].nil?
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
    render :json => accepted, :status => 200
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
      q_matchdata = /(.*)\s+(\([^\)]*\))(?:\s<<([^>]*)>>|)/.match q

      if q_matchdata.nil?
        puts "couldn't process:"
        puts q
        next
      end

      q_text = q_matchdata[1]
      q_ans = q_matchdata[2]
      q_hint = q_matchdata[3]

      as = q_ans.gsub(/^\(|\)$/, '').split /\sor\s|;\s/
      correct_ans = as.shift

      @question = Question.find_by_text q_text
      #next if @question

      @question = @asker.questions.create :text => q_text, :user_id => current_user.id, :hint => q_hint
      @question.answers.create :text => correct_ans, :correct => true
      as.each{|a| @question.answers.create :text => a, :correct => false}
    end

    render :text => questions.to_yaml
  end
end
