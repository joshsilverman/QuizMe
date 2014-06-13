if ($('.feed-view').length) {
  $(function() {
    var correctQIds = [],
      feedViewModel, askerId, currentUserId, publicationId;

    function init(subjectUrl, _askerId, _currentUserId, _publicationId) {
      var correctQIdsPath;

      askerId = _askerId;
      feedViewModel = new FeedViewModel();
      currentUserId = _currentUserId;
      publicationId = _publicationId;

      self.loadCorrectQIds = function() {
        if (!currentUserId) return;

        correctQIdsPath = "/users/" + currentUserId + "/correct_question_ids.json"
        $.getJSON(correctQIdsPath, function(_correctQIds) {
          correctQIds = _correctQIds;
          _.each(feedViewModel.feedPublications(), function(p) {p.markAnswered()});
        });
      };

      ko.applyBindings(feedViewModel, $('.feed-view')[0]);
      $(window).on('ios:refresh', feedViewModel.refresh);

      feedViewModel.loadPublications();
      feedViewModel.initLoadMore();
      self.loadCorrectQIds();
    }

    function FeedViewModel() {
      var self = this,
        offset = 0,
        loadMoreBtn = $('.load-more');

      self.loadingMore = ko.observable(false);
      self.feedPublications = ko.observableArray([]);
      self.askerId = askerId;

      self.initLoadMore = function() {
        var path = location.pathname.replace(/\/$/, '').split('/')
        if (_.last(path) == "quiz") return;

        $(window).on('DOMContentLoaded load resize scroll', 
          _.throttle(self.loadMorePublications, 250, {leading: true})); 
      };

      self.loadMorePublications = function() {
        if (!self.loadingMore() && isElementInViewport(loadMoreBtn[0])) {
          if (offset > 10)
            self.loadingMore(true);
          offset += 10;
          self.loadPublications();
        }
      };

      self.loadPublications = function(beforeRender, afterRender) {
        currentPath = location.pathname.replace(/\/$/, '') || 'feeds/index'; 
        path = currentPath + ".json" + "?offset=" + offset;
        path = path + "&" + location.search.replace(/^\?/, '');

        $.getJSON(path, function(publication) {
          if (beforeRender) {beforeRender()}

          publication.forEach(function(publication) {
            var feedPublication = new FeedPublicationModel(publication);
            self.feedPublications.push(feedPublication);
          });

          self.loadingMore(false);
          self.focusOnPublication();

          if (afterRender) {afterRender()}
        })
      };

      self.focusOnPublication = function() {
        if (offset > 0) return;
        if (!publicationId) return;

        var pub = $('.post[data-publication-id=' + publicationId + ']');
        $.scrollTo(pub);
      };

      self.refresh = function() {
        offset = 0;
        self.loadPublications(
          function() {self.feedPublications([])},
          function() {window.location.href = 'ios://refreshed'});
      };
    }

    function FeedPublicationModel(publication) {
      var self = this;
      
      self.id = publication.id;
      self.firstPostedAt = publication.first_posted_at;
      self.question = publication._question.text;
      self.questionId = parseInt(publication._question.id);
      self.correctAnswerId = parseInt(publication._question.correct_answer_id);
      self.subject = [publication._asker.subject, ':'].join("");
      self.subject_url = publication._asker.subject_url;
      self.answered = ko.observable(false);
      self.toldAnswer = ko.observable(false);
      self.quizHref = null;
      self.quizName = null;

      self.loadInteractions = function() {
        self.interactions = [];
        _.each(publication._activity, function(imageSrc, screenName) {
          self.interactions.push(new InteractionViewModel(screenName, imageSrc));
        });
      }

      self.loadAnswers = function() {
        self.answers = [];
        _.each(publication._answers, function(text, id) {
          attrs = {text: text,
            id: parseInt(id),
            publication_id: self.id}

          if (text) self.answers.push(new AnswerViewModel(attrs, self));
        });
        self.answers = _.shuffle(self.answers);
      }

      self.markAnswered = function() {
        if (!_.contains(correctQIds, self.questionId)) return;

        var correctAnswer = _.find(self.answers, function(answer) {
          return answer.id === self.correctAnswerId;
        });

        self.answered(true);
        correctAnswer.correct(true);
      };

      self.setQuizAttrs = function() {
        if (!publication._lesson) return;
        if (!publication._lesson.name) return;

        self.quizName = publication._lesson.name + ' Quiz'
        self.quizHref = '/' + self.subject_url 
          + '/' + publication._lesson.topic_url
          + '/quiz';
      };

      self.tellAnswer = function() {
        _.map(self.answers, function(answer) {
          if (answer.id === self.correctAnswerId) {} 
          else {
            answer.disabled(true);
          }
        });

        self.toldAnswer(true);
        self.answered(true);
        mixpanel.track("I dont know");
      };

      self.loadAnswers();
      self.loadInteractions();
      self.markAnswered();
      self.setQuizAttrs();
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
      self.disabled = ko.observable(false);
      
      self.respondToQuestion = function() {
        if (self.feedPublication.answered() === true) return;
        if (!currentUserId) {
          self.authenticate();
          return;
        }

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
        self.feedPublication.answered(status);
      }

      self.authenticate = function() {
        window.location.replace("/users/auth/twitter")
      }
    }

    function InteractionViewModel(screenName, imageSrc) {
      var self = this;
      self.twiScreenName = screenName;
      self.twiProfileImgUrl = imageSrc;
    }

    ko.bindingHandlers.timeago = {
      update: function(element, valueAccessor) {
        var value = ko.utils.unwrapObservable(valueAccessor()),
          $this = $(element);

        if (!$this.data('timeago')) {
          $this.attr('title', value);
          $this.timeago();
        }
      }
    };

    init($('.feed-view').data('subject-url'),
      $('.feed-view').data('asker-id'),
      $('.feed-view').data('current_user-id'),
      $('.feed-view').data('publication-id'));
  });
}