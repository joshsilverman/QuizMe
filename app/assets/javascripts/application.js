// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
//= require jquery
//= require jquery_ujs
//= require jquery.ui.autocomplete
//= require jquery.ui.datepicker
//= require lib/jquery.cookie
//= require lib/jquery.stellar
//= require lib/knockout-3.0.0.min
//= require lib/snap
//= require lib/jQuery.smartWebBanner
//= require lodash
//= require moment

//= require twitter/bootstrap
//= require best_in_place
//= require lib/pusher-2.1.min

//= require_tree .

if (!window.console) console = {log: function() {}}
puts = function(o) {console.log(o)}

function DummyMixpanel() {
  this.track = function() {};
  this.track_pageview = function() {};
  this.track_links = function() {};
  this.track_forms = function() {};
  this.register = function() {};
  this.register_once = function() {};
  this.unregister = function() {};
  this.identify = function() {};
  this.name_tag = function() {};
  this.set_config = function() {};
}

function readCookie(name) {
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');
  for(var i=0;i < ca.length;i++) {
    var c = ca[i];
    while (c.charAt(0)==' ') c = c.substring(1,c.length);
    if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
    return null
  }
}

function isElementInViewport (el) {
    var rect = el.getBoundingClientRect();

    return (
      rect.top >= 0 &&
      rect.left >= 0 &&
      rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) && /*or $(window).height() */
      rect.right <= (window.innerWidth || document.documentElement.clientWidth) /*or $(window).width() */
    );
}

setTimeout(
  function() {
    if ($('body.phone-variant').length > 0) return;

    $().smartWebBanner({
      title: "Wisr", // What the title of the "app" should be in the banner | Default: "Web App"
      titleSwap: false, // Whether or not to use the title specified here has the default label of the home screen icon (otherwise uses the page's <title> tag) | Default: true
      url: 'https://itunes.apple.com/us/app/wisr/id887180306', // URL to mask the page as before saving to home screen (allows for having it save the homepage of a site no matter what page the visitor is on) | Default: ''
      author: "Wisr", // What the author of the "app" should be in the banner | Default: "Save to Home Screen"
      speedIn: 0, // Show animation speed of the banner | Default: 300
      speedOut: 0, // Close animation speed of the banner | Default: 400
      daysHidden: 1, // Duration to hide the banner after being closed (0 = always show banner) | Default: 15
      daysReminder: 1, // Duration to hide the banner after "Save" is clicked *separate from when the close button is clicked* (0 = always show banner) | Default: 90
      useIcon: true, // Whether or not it should show site's apple touch icon (located via <link> tag) | Default: true
      // debug: true,
      iconOverwrite: "http://a5.mzstatic.com/us/r30/Purple/v4/fe/aa/81/feaa81a9-0821-d244-c577-5e386819380c/mzl.jihrktfn.175x175-75.jpg"
  })}, 800
)

jQuery.timeago.settings.strings = {
   prefixAgo: "",
   prefixFromNow: "",
   seconds: "just now",
   minute: "1m",
   minutes: "%dm",
   hour: "1h",
   hours: "%dh",
   day: "1d",
   days: "%dd",
   month: "1m",
   months: "%dm",
   year: "1y",
   years: "%dy"
};