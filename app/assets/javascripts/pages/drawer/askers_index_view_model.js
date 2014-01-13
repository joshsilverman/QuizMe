if ($('.drawer .askers-index').length > 0) {
  $(function() {
    var askersIndexViewModel;

    function init() {
      askersIndexViewModel = new AskersIndexViewModel();
      ko.applyBindings(askersIndexViewModel, $('.drawer .askers-index')[0]);

      $.getJSON("/askers.json", function(askers) {
        askers.forEach(function(asker) {
          var askerModel;
          if (!asker.published) return;
          
          askerModel = new AskerModel(asker);
          askersIndexViewModel.askers.push(askerModel);
        });
      })
    }

    function AskerModel(asker) {
      var self = this;
      self.twi_screen_name = asker.twi_screen_name
      self.href = '/feeds/' + asker.id
    }

    function AskersIndexViewModel() {
      var self = this;
      self.askers = ko.observableArray([]);
    }

    init();
  });
}