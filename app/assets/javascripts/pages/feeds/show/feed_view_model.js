if ($('#feed_content').length) {
  $(function() {
    var feedViewModel, asker, askerId;

    function init(subjectUrl, _askerId) {
      feedViewModel = new FeedViewModel();
      askerId = _askerId
      ko.applyBindings(feedViewModel, $('#feed_content')[0]);
      
      $.getJSON("/askers/" + askerId + ".json", function(a) {
        asker = new AskerModel(a);

        ko.utils.arrayForEach(feedViewModel.feedPublications(), function(pub) {
          pub.twiProfileImgUrl(asker.twiProfileImgUrl);
        })
      })

      feedViewModel.loadPublications();
      feedViewModel.initLoadMore();
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
      var self = this,
        offset = 0,
        loadingMore = true,
        loadMoreBtn = $('#posts_more');

      self.feedPublications = ko.observableArray([]);

      self.initLoadMore = function() {
        $(window).on('DOMContentLoaded load resize scroll', 
          _.throttle(self.loadMorePublications, 250, {leading: true})); 

        $("#posts_more").on("click", function(e) {
          e.preventDefault();
          self.loadMorePublications();
        });
      }

      self.loadMorePublications = function() {
        if (!loadingMore && isElementInViewport(loadMoreBtn[0])) {
          loadingMore = true;
          offset += 10;
          self.loadPublications();
        }
      }

      self.loadPublications = function() {
        path = location.pathname + ".json" + "?offset=" + offset;

        $.getJSON(path, function(publication) {
          publication.forEach(function(publication) {
            var feedPublication = new FeedPublicationModel(publication);
            self.feedPublications.push(feedPublication);
          });

          loadingMore = false;
        })
      }
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
        if (status) {
          self.correct(true);
          $(document).trigger('increment', 'answerCount');
        } else self.incorrect(true);

        self.grading(false);
        self.feedPublication.answered = status;
      }
    }

    function InteractionViewModel(screenName, imageSrc) {
      var self = this;
      self.twiScreenName = screenName;
      self.twiProfileImgUrl = imageSrc;
    }

    init($('#feed_content').data('subject-url'),
      $('#feed_content').data('asker-id'));
  });
}