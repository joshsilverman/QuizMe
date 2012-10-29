MIXPANEL_KEY = (Rails.env.production? ? "cc41ff876080a580c5d9ca257d189162" : "e568e52157e29acc604c236e9ce4cfa6")
Mixpanel = Mixpanel::Tracker.new MIXPANEL_KEY, {:async => true}