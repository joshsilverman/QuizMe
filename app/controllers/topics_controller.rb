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
    @asker = Asker.find_by_subject_url params[:subject]

    respond_to do |format|
      format.html do
      end

      format.json do
        lesson = Topic.find_by_topic_url params[:name]

        if lesson
          questions = lesson.questions.approved  
          render json: questions.to_json
        else
          head status: 404
        end 
      end
    end
  end
end
