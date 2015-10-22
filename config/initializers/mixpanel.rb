MIXPANEL_KEY = ENV['MIXPANEL_KEY']
MP = Mixpanel::Tracker.new MIXPANEL_KEY, {:async => true}
