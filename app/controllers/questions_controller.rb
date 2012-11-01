class QuestionsController < ApplicationController
  before_filter :authenticate_user, :except => [:new, :refer, :show]
  before_filter :admin?, :only => [:moderate, :moderate_update]
  before_filter :author?, :only => [:index]


  def index
    @questions = current_user.questions.includes(:answers).order("created_at DESC").page(params[:page]).per(25)
    @questions_hash = Hash[@questions.collect{|q| [q.id, q]}]
    @handle_data = User.askers.collect{|h| [h.twi_screen_name, h.id]}

    respond_to do |format|
      format.html
      format.json { render json: @questions }
    end
  end

  def show
    @question = Question.find(params[:id])
    @asker = User.find(@question.created_for_asker_id)
    @publication = Publication.where(:question_id => params[:id], :published => true).order("created_at DESC").limit(1).first
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

  # def import_data_from_qmm
  #   questions = Question.import_data_from_qmm
  #   qs = questions
  #   qs.each do |q|
  #     real_q = Question.find_by_text(q['question']['question'])
  #     next unless real_q
  #     real_q.update_attributes(:qb_lesson_id => q['question']['lesson_id'],
  #                              :qb_q_id => q['question']['q_id'])

  #     unless q['question']['posts'].nil? or q['question']['posts'].empty?
  #       q['question']['posts'].each do |p|
  #         new_p = Post.create(:asker_id => p['post']['account_id'].to_i+100,
  #               :question_id => real_q.id,
  #               :to_twi_user_id => p['post']['to_twi_user_id'].to_i,
  #               :provider => p['post']['provider'],
  #               :text => p['post']['text'],
  #               :url => p['post']['url'],
  #               :link_type => p['post']['link_type'],
  #               :post_type => p['post']['post_type'],
  #               :provider_post_id => p['post']['provider_post_id'])
  #         if p['post']['mentions']
  #           p['post']['mentions'].each do |m|
  #             u = User.find_or_create_by_twi_screen_name(m['mention']['user']['twi_screen_name'])
  #             u.update_attributes(:twi_user_id => m['mention']['user']['twi_user_id'],
  #                                 :twi_name => m['mention']['user']['twi_name'],
  #                                 :twi_profile_img_url => m['mention']['user']["profile_img_url"])
  #             new_m = Mention.create(:user_id => u.id,
  #                                    :post_id => new_p.id,
  #                                    :text => m['mention']['text'],
  #                                    :responded => m['mention']['responded'],
  #                                    :twi_tweet_id => m['mention']['twi_tweet_id'],
  #                                    :twi_in_reply_to_status_id => m['mention']['twi_in_reply_to_status_id'])
  #             rep = Rep.create(:user_id => u.id,
  #                              :post_id => new_p.id,
  #                              :correct => m['mention']['correct']) unless m['mention']['correct'].nil?
  #           end
  #         end
  #       end
  #     end
  #   end
  #   render :json => questions
  # end
end
