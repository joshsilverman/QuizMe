if ($('#activity_stream:visible').length > 0) {
  $(function() {

    function init() {
      var streamViewModel = new StreamViewModel();

      ko.applyBindings(streamViewModel);

      $.getJSON("/feeds/stream", function(posts) {
        posts.forEach(function(post) {
          var streamPost = new StreamPostModel(post)
          streamViewModel.streamPosts.push(streamPost);
        });
      })
    }

    function StreamPostModel(post) {
      var self = this;

      self.created_at = post.created_at;
      self.questionText = post.in_reply_to_question.text;
      self.user_twi_screen_name = post.user.twi_screen_name;
      self.user_twi_profile_img_url = post.user.twi_profile_img_url;

      self.href = "/questions/" + post.in_reply_to_question.id;

      $("#activity_stream .content").dotdotdot({height: 55});
    }

    function StreamViewModel() {
      var self = this;

      self.streamPosts = ko.observableArray([]);
    }

    ko.bindingHandlers.timeago = {
      update: function(element, valueAccessor) {
        var value = ko.utils.unwrapObservable(valueAccessor());

        var $this = $(element);

        $this.attr('title', value);

        if ($this.data('timeago')) {
          var datetime = $.timeago.datetime($this);
          var distance = (new Date().getTime() - datetime.getTime());
          var inWords = $.timeago.inWords(distance);

          $this.data('timeago', { 'datetime': datetime });
          $this.text(inWords);
        } else {
          $this.timeago();
        }
      }
    };

    ko.bindingHandlers.dotdotdot = {
      update: function(element, valueAccessor) {
        var value = ko.utils.unwrapObservable(valueAccessor());

        var $this = $(element);

        $this.text(value);
        $this.parent().dotdotdot({height: 55})
      }
    };

    init();
  });
}