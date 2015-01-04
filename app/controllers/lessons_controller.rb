class LessonsController < ApplicationController
  before_filter :authenticate_user!, :except => [:show]
  skip_before_filter :verify_authenticity_token, :only => [:create, :update]

  def create
    respond_to do |f|
      f.json do
        topic = Topic.new(
          type_id: params[:type_id], 
          published: false, 
          user_id: current_user.id, 
          asker_id: params[:asker_id], 
          name: params[:name])

        if !topic.save 
          render status: 400, json: topic.errors
          return
        end

        question = topic.questions.create!(
          created_for_asker_id: params[:asker_id], 
          user: current_user)
        question.answers.create! correct: true
        question.answers.create! correct: false

        render json: topic.to_json
      end
    end
  end

  def update
    topic = current_user.lessons.where(id: params[:id]).first
    topic ||= Topic.find(params[:id]) if current_user.is_role? 'admin'

    if topic.nil?
      head :unauthorized
      return
    end
    
    respond_to do |f|
      f.json do
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
      format.json do
        @lesson = Topic.find params[:id]

        if @lesson
          questions = @lesson.questions.includes(:user)
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
end
