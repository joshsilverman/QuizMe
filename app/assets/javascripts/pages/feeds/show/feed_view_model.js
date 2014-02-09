if ($('.feed_section').length > 0) {
  $(function() {
    var feedViewModel, asker, askerId;

    function init(subjectUrl, _askerId) {
      feedViewModel = new FeedViewModel();
      askerId = _askerId
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
      self.answered = undefined;

      self.interactions = [];
      _.each(publication._activity, function(imageSrc, screenName) {
        self.interactions.push(new InteractionViewModel(screenName, imageSrc));
      });

      self.answers = [];
      _.each(publication._answers, function(text, id) {
        attrs = {text: text,
          id: parseInt(id),
          publication_id: publication.id}

        if (text) self.answers.push(new AnswerViewModel(attrs, self));
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

    function AnswerViewModel(attrs, feedPublication) {
      var self = this;
      self.text = attrs.text;
      self.id = attrs.id;
      self.publication_id = attrs.publication_id;
      self.feedPublication = feedPublication;

      self.grading = ko.observable(false);
      self.correct = ko.observable(false);
      self.incorrect = ko.observable(false);
      
      self.respondToQuestion = function() {
        if (self.feedPublication.answered === true)
          return;

        params = {"asker_id" : askerId,
          "publication_id" : self.publication_id,
          "answer_id" : self.id};

        self.grading(true);
        $.post('/respond_to_question', params, self.renderResults);};

      self.renderResults = function(status) {
        if (status) self.correct(true);
        else self.incorrect(true);

        self.grading(false);
        self.feedPublication.answered = status;
      }
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