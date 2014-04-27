if ($('.lessons:visible').length > 0) {
  $(function() {
    var lessonsViewModel, askerId, subjectUrl;

    function init(_askerId) {
      askerId = _askerId;
      lessonsViewModel = new LessonsViewModel();

      ko.applyBindings(lessonsViewModel, $('.lessons')[0]);

      $.getJSON("/topics?scope=lessons&asker_id=" + askerId, function(lessons) {
        subjectUrl = lessons['meta']['subject_url']
        lessons['topics'].forEach(function(lesson) {
          var lessonModel = new LessonModel(lesson);
          lessonsViewModel.lessons.push(lessonModel);
        });

        lessonsViewModel.update_answered_count();
      })

      $(document).on('increment', lessonsViewModel.update_answered_count);
    }

    function LessonModel(lesson) {
      var self = this;

      self.id = lesson.id
      self.name = lesson.name;
      self.answered_count = ko.observable('');
      self._question_count = lesson._question_count;

      self.goToLesson = function() {
        document.location.href = self.href;
      };

      self.href = "/" + subjectUrl + "/" + lesson.topic_url + "/quiz";
    }

    function LessonsViewModel() {
      var self = this;

      self.lessons = ko.observableArray([]);

      self.update_answered_count = function() {
        $.getJSON("/topics/answered_counts", function(answered_counts) {
          console.log('update answered_counts');
          ko.utils.arrayForEach(self.lessons(), function(lesson) {
            lesson.answered_count(answered_counts[lesson.id] || 0)
          });
        });
      }
    }

    ko.bindingHandlers.dotdotdot = {
      update: function(element, valueAccessor) {
        var value = ko.utils.unwrapObservable(valueAccessor());

        var $this = $(element);

        $this.text(value);
        $this.dotdotdot({height: 55})
      }
    };

    ko.bindingHandlers.fadeIn = {
      init: function(element, valueAccessor) {
        setTimeout(function() {
            $(element).addClass('appear');
          }, 150);
      }
    };

    init($('.lessons').data('askerid'));
  });
}