class ExperimentsController < ApplicationController
  before_filter :admin?, :except => [:index, :trigger]
  before_filter :yc_admin?, :only => :index

  def index
    @experiments = Split::Experiment.all
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