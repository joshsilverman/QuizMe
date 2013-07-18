class AskersQuestions
	constructor: ->
		@id = $("#asker_id").val()
		$('#askers_select select').on "change", -> window.location = "/askers/#{$(this).children(':selected').attr('value')}/questions"
		$("#question_input").on "focus", => $(".answer_area").show()
		$("#add_answer, #submit_question").off "click"
		$("#add_answer").on "click", => @add_answer()

		$("#submit_question").on "click", (e) => 
			e.preventDefault()
			@submit()
		$('.best_in_place').on "ajax:success", (e) => $(e.target).parents(".post").find(".status").removeClass("label-success label-important").addClass("label").text("Pending")
	add_answer: =>
		count = $(".answer_area .answer").length
		return if count > 3
		clone = $("#ianswer1").clone().attr("id", "ianswer#{count}").appendTo("#answers")
		clone.find("input").attr("name", "ianswer#{count}").val("").focus()
		$("#add_answer").hide() if count == 3
	submit: =>
		if @validate_form()
			$("#submit_question").button("loading")
			data =
				"question" : $("#question_input").val()
				"asker_id" : window.askers_questions.id
				"status" : $("#status").val()
				"canswer" : $("#canswer input").val()
				"ianswer1" : $("#ianswer1 input").val()
				"ianswer2" : $("#ianswer2 input").val()
				"ianswer3" : $("#ianswer3 input").val()
			$("#submit_question").button("loading")
			modal = $("#post_question_modal")
			modal.find(".modal-body").slideToggle(250)
			$.ajax
				url: "/questions/save_question_and_answers",
				type: "POST",
				data: data,
				error: => alert "Sorry, something went wrong!",
				success: (e) => document.location.reload(true)
	validate_form: =>
		if $("#question_input").val() == ""
			alert "Please enter a question!"
			return false
		else if $("#canswer input").val().length == 0 or $("#ianswer1 input").val().length == 0
			alert "Please enter at least one correct and incorrect answer!"
			return false
		else
			return true	

$ -> 
	if $('#author_dashboard').length > 0
		window.askers_questions = new AskersQuestions 
		target = $(".post[question_id=#{$('#question_id').val()}]")
		$('html,body').animate({scrollTop: target.offset().top - 10}, 1000) if target.length > 0