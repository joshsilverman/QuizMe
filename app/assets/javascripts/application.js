// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
//= require jquery
//= require jquery_ujs
//= require jquery.ui.autocomplete
//= require twitter/bootstrap
//= require best_in_place
//= require_tree .

if (!window.console) console = {log: function() {}}

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


function js_check(){
	// console.log('CHECK')
	var jsconfirm = readCookie('jsconfirm');
	// console.log(jsconfirm);
	if(jsconfirm == null){
		console.log('null... Sending AJAX request')
		confirm_js();
	}
}

function confirm_js(){
	$.ajax({
	  url: '/confirm_js',
	  type: 'GET', 
	  beforeSend: function(xhr) {
    	xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'));
  	},
	  success: function(data) {
	    // console.log('JS Success');
	    document.cookie = "jsconfirm=confirmed"
	  }
	});
}

puts = function(o) {console.log(o)}

js_check();
	//$.ajax '/confirm_js',
	//		type: 'POST'
	//		data: responseHash
	//		beforeSend: ()->
	//			console.log "beforeSend"
	//		error: (jqXHR, textStatus, errorThrown) ->
	//			console.log "AJAX Error: #{errorThrown}"
	//		success: (data, textStatus, jqXHR) =>
	//			console.log "Success"
	//			console.log data