if ($('#activity_stream:visible').length > 0) {
  $(function() {
    var streamViewModel;

    function init() {
      streamViewModel = new StreamViewModel();

      ko.applyBindings(streamViewModel, $('#activity_stream')[0]);

      $.getJSON("/feeds/stream", function(posts) {
        posts.forEach(function(post) {
          var streamPost = new StreamPostModel(post);
          streamViewModel.streamPosts.push(streamPost);
        });
      })

      subscribeToStream();
    }

    function StreamPostModel(post) {
      var self = this;

      self.created_at = post.created_at;
      self.questionText = post.in_reply_to_question.text;
      self.user_twi_screen_name = post.user.twi_screen_name;
      self.user_twi_profile_img_url = post.user.twi_profile_img_url;

      self.href = "/questions/" + post.in_reply_to_question.id;
    }

    function StreamViewModel() {
      var self = this;

      self.streamPosts = ko.observableArray([]);
    }

    function subscribeToStream() {
      try {
        var channel = pusher.subscribe('stream');
        channel.bind('answer', function(post) {
          var streamPost = new StreamPostModel(post); 
          streamViewModel.streamPosts.unshift(streamPost);

          setTimeout(function() {
              streamViewModel.streamPosts.pop();
            }, 1000);
        });
      } catch(err) {}
    }

    ko.bindingHandlers.dotdotdot = {
      update: function(element, valueAccessor) {
        var value = ko.utils.unwrapObservable(valueAccessor());

        var $this = $(element);

        $this.text(value);
        $this.parent().dotdotdot({height: 55})
      }
    };

    ko.bindingHandlers.fadeIn = {
      init: function(element, valueAccessor) {
        setTimeout(function() {
            $(element).addClass('appear');
          }, 150);
      }
    };

    init();
  });
}