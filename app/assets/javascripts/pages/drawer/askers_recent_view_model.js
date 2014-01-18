if ($('.drawer .askers-recent').length > 0) {
  $(function() {
    var askersRecentViewModel;

    function init() {
      askersRecentViewModel = new AskersRecentViewModel();
      ko.applyBindings(askersRecentViewModel, $('.drawer .askers-recent')[0]);

      $.getJSON("/askers/recent.json", function(askers) {
        askers.forEach(function(asker) {
          var askerModel;
          if (!asker.published) return;
          
          askerModel = new AskerModel(asker);
          askersRecentViewModel.askers.push(askerModel);
        });
      })
    }

    function AskerModel(asker) {
      var self = this;
      self.twi_screen_name = asker.twi_screen_name
      self.href = '/feeds/' + asker.id
    }

    function AskersRecentViewModel() {
      var self = this;
      self.askers = ko.observableArray([]);
    }

    init();
  });
}