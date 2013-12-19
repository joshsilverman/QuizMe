class Asker
	constructor: ->
		@user_id = parseInt $('#user_id').attr('value')
		$('.pay').click @pay
		$('#import').click @import

		$("abbr.timeago").timeago();

	pay: (e) =>
		mixpanel.track "tutor-submit-payment-form",
			distinct_id: @user_id

		e.preventDefault()
		$('input, select, .pay').attr "disabled", true
		$('.pay').text "Processing..."
		setTimeout -> 
				$('.payment-errors').show()
			, 1000

	import: ->
		seeder_id = prompt "What is the handle id you'd like to import?", "123"
		$.post "/askers/#{$('#asker_id').attr("value")}/import", 
			seeder_id: seeder_id 

$ -> 
	window.asker = new Asker

	# # @temp styling
	# $('#wrapper').css minHeight: $(document).height() - 40
	# $('body').css paddingBottom: 0