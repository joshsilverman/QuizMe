if Rails.env.production?
	Mixpanel = Mixpanel::Tracker.new "cc41ff876080a580c5d9ca257d189162", {}
else
	Mixpanel = Object.new
	def Mixpanel.track_event() end
end