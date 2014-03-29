# This file is used by Rack-based servers to start the application.

GC_FREQUENCY = 15
require_dependency 'unicorn/oob_gc'
GC.disable # Don't run GC during requests
use Unicorn::OobGC, GC_FREQUENCY # Only GC once every GC_FREQUENCY requests

require ::File.expand_path('../config/environment',  __FILE__)
run Quizmemanager::Application
