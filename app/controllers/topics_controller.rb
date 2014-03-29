class TopicsController < ApplicationController
  def index
    respond_to do |format|
      format.json do
        asker = Asker.find params[:asker_id]
        topics = asker.topics

        if params[:scope] == 'lessons'
          topics = topics.lessons
        end

        render json: topics.to_json
      end
    end
  end

  def show
    respond_to do |format|
      format.html { render nothing: true }
      format.json do
        lesson = Topic.lessons
          .where(name: params[:name]).includes(:questions).first
          
        render json: lesson.to_json(include: :questions)
      end
    end
  end
end
