class Asker
	constructor: ->
		$('#import').click @import

		$("abbr.timeago").timeago();

	import: ->
		seeder_id = prompt "What is the handle id you'd like to import?", "123"
		$.post "/askers/#{$('#asker_id').attr("value")}/import", 
			seeder_id: seeder_id 

$ -> 
	window.asker = new Asker