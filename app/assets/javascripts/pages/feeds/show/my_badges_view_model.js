if ($('#my_badges:visible').length > 0) {
  $(function() {
    var myBadgesViewModel;

    function init() {
      myBadgesViewModel = new MyBadgesViewModel();


      ko.applyBindings(myBadgesViewModel, $('#my_badges')[0]);

      $.getJSON("/issuances.json", function(issuances) {
        issuances.forEach(function(issuance) {
          var badge = new BadgeModel(issuance);
          myBadgesViewModel.badges.push(badge);
        });
      })
    }

    function BadgeModel(issuance) {
      var self = this;

      self.issuance_id = issuance.created_at;
      self.title = issuance.badge.title;
      self.description = issuance.badge.description;
      self.href = "/assets/" + issuance.badge.filename;
    }

    function MyBadgesViewModel() {
      var self = this;

      self.badges = ko.observableArray([]);
    }

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