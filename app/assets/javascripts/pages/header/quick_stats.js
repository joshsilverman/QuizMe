if ($('.quick-stats').length > 0) {
  $(function() {
    var quickStatsViewModel;

    function init(user_id) {
      quickStatsViewModel = new QuickStatsViewModel();
      ko.applyBindings(quickStatsViewModel, $('.quick-stats')[0]);

      $.getJSON("/users/" + user_id + "/posts/answer_count", function(count) {
        quickStatsViewModel.answer_count(count);
      })

      $.getJSON("/users/" + user_id + "/moderations/count", function(count) {
        quickStatsViewModel.moderation_count(count);
      })

      $.getJSON("/users/" + user_id + "/questions/count", function(count) {
        quickStatsViewModel.question_count(count);
      })

    }

    function QuickStatsViewModel() {
      var self = this;

      self.answer_count = ko.observable();
      self.question_count = ko.observable();
      self.moderation_count = ko.observable();
    }

    init($('#current_user_id').val());
  });
}