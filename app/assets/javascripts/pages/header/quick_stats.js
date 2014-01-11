if ($('.quick-stats').length > 0) {
  $(function() {
    var quickStatsViewModel;

    function init(user_id) {
      quickStatsViewModel = new QuickStatsViewModel();
      ko.applyBindings(quickStatsViewModel, $('.quick-stats')[0]);

      $.each(['.answer-count', '.moderation-count', '.question-count'], function(i, selector) {
        var $this = $(selector),
          dataSource = $this.attr('data-source'),
          dataTarget = $this.attr('data-target');

        $.getJSON("/users/" + user_id + dataSource, function(count) {
          quickStatsViewModel[dataTarget](count);
          $this.addClass('visible');
          $(selector + ' + .circle').addClass('visible');
        })
      });

      $('.quick-stat').tooltip();
    }

    function QuickStatsViewModel() {
      var self = this;

      self.answerCount = ko.observable();
      self.questionCount = ko.observable();
      self.moderationCount = ko.observable();
    }

    init($('#current_user_id').val());
  });
}