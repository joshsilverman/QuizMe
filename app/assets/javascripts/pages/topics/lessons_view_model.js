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
      })
    }

    function LessonModel(lesson) {
      var self = this;

      self.name = lesson.name;
      self.completeness = lesson._question_count;

      self.goToLesson = function() {
        document.location.href = self.href;
      };

      self.href = "/" + subjectUrl + "/" + lesson.topic_url + "/quiz";
    }

    function LessonsViewModel() {
      var self = this;

      self.lessons = ko.observableArray([]);
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