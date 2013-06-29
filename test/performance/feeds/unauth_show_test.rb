require 'test_helper'
# require 'rails/performance_test_help'
# require 'minitestbund_helper'
# require 'active_support/number_helper'

# puts ActionDispatch
# puts ActionDispatch::PerformanceTest

class UnauthShow < ActionDispatch::PerformanceTest
  # Refer to the documentation for all available options
  # self.profile_options = { :runs => 1, :metrics => [:wall_time, :memory]\
  #                          :output => 'tmp/performance', :formats => [:flat] }
  
  # user = FactoryGirl.create(:user)
  # wisr = FactoryGirl.create(:wisr)
  Rails.cache.clear

  def test_homepage
    get '/feeds/10565/63801'
  end
end