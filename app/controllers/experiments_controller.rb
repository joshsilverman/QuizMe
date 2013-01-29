class ExperimentsController < ApplicationController
  # before_filter :admin?

  def index
    @experiments = Split::Experiment.all
  end

  def conclude
    @experiment = Split::Experiment.find(params[:experiment])
    @alternative = Split::Alternative.new(params[:alternative], params[:experiment])
    @experiment.winner = @alternative.name
    redirect_to '/experiments'
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