if ($('.feed_section').length > 0) {
  $(function() {
    var feedViewModel, asker;

    function init(subjectUrl, askerId) {
      feedViewModel = new FeedViewModel();
      ko.applyBindings(feedViewModel, $('.feed_section')[0]);
      
      $.getJSON("/askers/" + askerId + ".json", function(a) {
        asker = new AskerModel(a);

        ko.utils.arrayForEach(feedViewModel.feedPublications(), 
          function(feedPublication) {

          feedPublication.twiProfileImgUrl(asker.twiProfileImgUrl);
        })
      })

      $.getJSON("/" + subjectUrl + ".json", function(publication) {
        publication.forEach(function(publication) {
          var feedPublication = new FeedPublicationModel(publication);
          feedViewModel.feedPublications.push(feedPublication);
        });
      })
    }

    function FeedPublicationModel(publication) {
      var self = this;
      
      self.createdAt = publication.created_at;
      self.question = publication._question.text;

      self.interactions = [];
      _.each(publication._activity, function(imageSrc, screenName) {
        self.interactions.push(new InteractionViewModel(screenName, imageSrc));
      });

      self.answers = [];
      _.each(publication._answers, function(text, id) {
        if (text) self.answers.push(new AnswerViewModel(text, id));
      });
      self.answers = _.shuffle(self.answers);

      self.twiProfileImgUrl = ko.observable('');
      if (asker){
        self.twiProfileImgUrl = ko.observable(asker.twiProfileImgUrl);
      }
    }

    function FeedViewModel() {
      var self = this;
      self.feedPublications = ko.observableArray([]);
    }

    function AskerModel(asker) {
      var self = this;
      self.twiProfileImgUrl = asker.twi_profile_img_url;
    }

    function AnswerViewModel(text, id) {
      var self = this;
      self.text = text;
      self.id = id;

      self.respondToQuestion = function() {
        console.log('there');
      };
    }

    function InteractionViewModel(screenName, imageSrc) {
      var self = this;
      self.twiScreenName = screenName;
      self.twiProfileImgUrl = imageSrc;
    }

    // ko.bindingHandlers.timeago = {
    //   update: function(element, valueAccessor) {
    //     var value = ko.utils.unwrapObservable(valueAccessor());

    //     var $this = $(element);
    //     $this.attr('title', value);

    //     if ($this.data('timeago')) {
    //       var datetime = $.timeago.datetime($this);
    //       var distance = (new Date().getTime() - datetime.getTime());
    //       var inWords = $.timeago.inWords(distance);

    //       $this.data('timeago', { 'datetime': datetime });
    //       $this.text(inWords);
    //     } else {
    //       $this.timeago();
    //     }
    //   }
    // };

    init($('.feed_section').data('subject-url'),
      $('.feed_section').data('asker-id'));
  });
}