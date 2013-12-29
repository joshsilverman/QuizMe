if ($('.issuance-container').length > 0) {
  $(function() {
    var issuanceViewModel;

    function init(id) {
      issuanceViewModel = new IssuanceViewModel();
      ko.applyBindings(issuanceViewModel);

      $.getJSON("/issuances/" + id, function(issuance) {
        issuanceViewModel.created_at(
          moment(issuance.created_at).format("MMMM Do YYY")
        );

        issuanceViewModel.title(issuance.badge.title);
        issuanceViewModel.source("/assets/" + issuance.badge.filename);
        issuanceViewModel.description(issuance.badge.description);

        issuanceViewModel.user_twi_profile_img_url(issuance.user.twi_profile_img_url);
        issuanceViewModel.user_twi_screen_name("@" + issuance.user.twi_screen_name);

        $('.issuance .content').removeClass('hidden');
      })
    }

    function IssuanceViewModel() {
      var self = this;

      self.created_at = ko.observable();
      self.title = ko.observable();
      self.description = ko.observable();
      self.user_twi_screen_name = ko.observable();
      self.source = ko.observable();
      self.user_twi_profile_img_url = ko.observable();
    }

    init($('.issuance-container .issuance').attr('issuance_id'));
  });
}