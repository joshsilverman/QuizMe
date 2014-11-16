class TopicsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  skip_before_filter :verify_authenticity_token, :only => [:create, :update]

  def index
    respond_to do |format|
      format.json do
        @asker = Asker.find params[:asker_id]
        topics = @asker.topics

        if params[:scope] == 'lessons'
          topics = topics.lessons
        end

        render json: topics.order(id: :asc),
          meta: {subject_url: @asker.subject_url}
      end
    end
  end

  def create
    respond_to do |f|
      f.json do
        topic = Topic.new(
          type_id: params[:type_id], 
          published: false, 
          user_id: current_user.id, 
          asker_id: params[:asker_id], 
          name: params[:name])

        if topic.save
          render json: topic.to_json
        else
          render status: 400, json: topic.errors
        end
      end
    end
  end

  def update
    respond_to do |f|
      f.json do
        topic = Topic.find(params[:id])
        safe_params = params.permit(:name, :published)

        if topic.update safe_params
          render json: topic.to_json
        else
          render status: 400, json: topic.errors
        end
      end
    end
  end

  def show
    respond_to do |format|
      format.html do
        url = "#{FEED_URL}#{request.fullpath}"
        redirect_to url, status: 301
      end

      format.json do
        @lesson = Topic.find_by_topic_url params[:name]
        @lesson ||= Topic.find params[:id]

        if @lesson
          questions = @lesson.questions.approved.includes(:user)
          render json: questions,
            each_serializer: QuestionAsPublicationSerializer,
            root: false,
            lesson: @lesson
        else
          head status: 404
        end
      end
    end
  end

  def answered_counts
    records = current_user.posts.where(correct: true).where('in_reply_to_question_id IS NOT NULL').select(['count(distinct questions.id) as question_count', 'questions_topics.topic_id as topic_id']).joins(in_reply_to_question: :questions_topics).group(['questions_topics.topic_id'])
    lesson_counts = {}
    records.each do |record|
      lesson_counts[record.topic_id] = record.question_count
    end
    lesson_counts
    render json: lesson_counts
  end
end
