class ExperimentsController < ApplicationController
  before_filter :admin?, :except => [:index, :trigger]

  def index
    @experiments = Split::Experiment.all.reject { |e| e.blank? or e.name.include? 'search term' }
  end

  def index_concluded
    @concluded = true
    @experiments = Split::Experiment.all
    render "_experiments", layout: false
  end

  def index_search_terms
    @experiments = Split::Experiment.all.select { |e| e.present? and e.name.include? 'search term' }
    render "_experiments", layout: false
  end

  def index_concluded_search_terms
    @concluded = true
    @experiments = Split::Experiment.all.select { |e| e.present? and e.name.include? 'search term' }
    render "_experiments", layout: false
  end

  def show
    @experiment = Split::Experiment.find params[:name]
    render "_experiment", layout: false
  end

  def conclude
    @experiment = Split::Experiment.find(params[:experiment])
    @alternative = Split::Alternative.new(params[:alternative], params[:experiment])
    @experiment.winner = @alternative.name
    redirect_to '/experiments'
  end

  def trigger
    finished params[:experiment]
    render nothing: true
  end

  def reset
    @experiment = Split::Experiment.find(params[:experiment])
    @experiment.reset
    redirect_to '/experiments'
  end

  def destroy
    @experiment = Split::Experiment.find(params[:experiment])
    @experiment.delete
    redirect_to '/experiments'
  end
end