class NewQuestionModal
  constructor: ->
    $(".post_question").on "click", (e) =>
      if $("#user_name").val() != undefined
        e.preventDefault()
        @post_question()

    @post_question() if $("#question_form").val() == "true"
  
    $(".post_another").on "click", => @post_another()

  post_question: (text = null, post_id = null) =>
    $("#question_input").val(text) if text
    $("#post_question_modal").modal()
    $("#question_input").focus() unless $("#manager").length > 0
    $("#add_answer, #submit_question").off "click"
    $("#add_answer").on "click", => add_answer()
    
    if post_id? # displays conversation history when mgr
      $(".modal_conversation_history").show()
      convo =  window.feed.conversations[post_id]
      $('.modal_conversation_history > .conversation').html('')
      user_post = window.feed.engagements[@id]
      $.each convo['posts'], (i, p) ->
        subsidiary = $("#subsidiary_template").clone().addClass("subsidiary").removeAttr("id")
        subsidiary.find("p").text("#{p['text']}") 
        subsidiary.find("h5").text("#{convo['users'][p['user_id']]['twi_screen_name']}")
        image = convo['users'][p['user_id']]['twi_profile_img_url']
        subsidiary.find("img").attr("src", image) unless image == null
        $('.modal_conversation_history').find(".conversation").append(subsidiary.show())
        if i == 0 and convo['answers'].length > 0
          html = "<div class='subsidiary post'>"
          $.each convo['answers'], (j, a) ->
            html+= "<div class='answers rounded border'><h3 style='#{'color: green;' if a['correct']}'>#{a['text']}</h3></div>"
          html += "</div>"
          $('.modal_conversation_history').find(".conversation").append(html)   

    $("#submit_question").on "click", (e) => 
      e.preventDefault()
      submit()

    add_answer = ->
      count = $("#post_question_modal .answer").length
      return if count > 3
      clone = $("#ianswer1").clone().attr("id", "ianswer#{count}").appendTo("#answers")
      clone.find("input").attr("name", "ianswer#{count}").val("").focus()
      $("#add_answer").hide() if count == 3

    submit = ->
      if validate_form()
        $("#submit_question").button("loading")
        data =
          "question" : $("#question_input").val()
          "asker_id" : $("#asker_id").val()
          "status" : $("#status").val()
          "canswer" : $("#canswer input").val()
          "ianswer1" : $("#ianswer1 input").val()
          "ianswer2" : $("#ianswer2 input").val()
          "ianswer3" : $("#ianswer3 input").val()
        data["post_id"] = post_id if post_id
        $("#submit_question").button("loading")
        modal = $("#post_question_modal")
        modal.find(".modal-body").slideToggle(250)
        $.ajax
          url: "/questions/save_question_and_answers",
          type: "POST",
          data: data,
          error: => alert "Sorry, something went wrong!",
          success: (e) => 
            $("#question_input, #canswer input, #ianswer1 input, #ianswer2 input, #ianswer3 input").val("")
            if post_id
              window.feed.post_another()
              modal.modal('hide') 
              $(".post[post_id=#{post_id}]").parent().css("opacity", 0.8)
            else
              modal.find(".question_form").hide()
              modal.find(".message").show()
              modal.find(".modal-body").slideToggle(250)

    validate_form = ->
      if $("#question_input").val() == ""
        alert "Please enter a question!"
        return false
      else if $("#canswer input").val().length == 0 or $("#ianswer1 input").val().length == 0
        alert "Please enter at least one correct and incorrect answer!"
        return false
      else
        return true

  post_another: =>
    modal = $("#post_question_modal")
    $('#submit_question').button('reset')
    modal.find(".modal-body").slideToggle(250, =>
      modal.find(".message").hide()
      modal.find(".question_form").show()
    ).delay(250).slideToggle(250, => $("#question_input").focus())

$ ->
  if $("#post_question_modal").length > 0
    window.new_question_modal = new NewQuestionModal
