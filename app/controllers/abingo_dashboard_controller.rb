class AbingoDashboardController < ApplicationController

  before_filter :admin?
  
  include Abingo::Controller::Dashboard

end