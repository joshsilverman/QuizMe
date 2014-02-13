if ($('#feed_content').length) {
  $(function() {
    var correctQIds = [],
      feedViewModel, askerId, currentUserId;

    function init(subjectUrl, _askerId, _currentUserId) {
      var correctQIdsPath;

      feedViewModel = new FeedViewModel();
      askerId = _askerId;
      currentUserId = _currentUserId;

      self.loadCorrectQIds = function() {
        if (!currentUserId) return;

        correctQIdsPath = "/users/" + currentUserId + "/correct_question_ids.json"
        $.getJSON(correctQIdsPath, function(_correctQIds) {
          correctQIds = _correctQIds;
          _.each(feedViewModel.feedPublications(), function(p) {p.markAnswered()});
        });
      };

      ko.applyBindings(feedViewModel, $('#feed_content')[0]);

      feedViewModel.loadPublications();
      feedViewModel.initLoadMore();
      self.loadCorrectQIds();
    }

    function FeedPublicationModel(publication) {
      var self = this;
      
      self.id = publication.id;
      self.firstPostedAt = publication.first_posted_at;
      self.question = publication._question.text;
      self.questionId = parseInt(publication._question.id);
      self.correctAnswerId = parseInt(publication._question.correct_answer_id);
      self.twiProfileImgUrl = publication._asker.twi_profile_img_url
      self.answered = undefined;

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

        self.answered = true;
        correctAnswer.correct(true);
      };

      self.loadAnswers();
      self.loadInteractions();
      self.markAnswered();
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
        currentPath = location.pathname.replace(/\/$/, '') || 'feeds/index'; 
        path = currentPath + ".json" + "?offset=" + offset;

        $.getJSON(path, function(publication) {
          publication.forEach(function(publication) {
            var feedPublication = new FeedPublicationModel(publication);
            self.feedPublications.push(feedPublication);
          });

          loadingMore = false;
        })
      }
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
        if (self.feedPublication.answered === true) return;
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
        self.feedPublication.answered = status;
      }

      self.authenticate = function() {
        window.location.replace("/users/auth/twitter"
          + "?feed_id=" + askerId
          + "&publication_id=" + self.feedPublication.id)
      }
    }

    function InteractionViewModel(screenName, imageSrc) {
      var self = this;
      self.twiScreenName = screenName;
      self.twiProfileImgUrl = imageSrc;
    }

    ko.bindingHandlers.timeago = {
      update: function(element, valueAccessor) {
        var value = ko.utils.unwrapObservable(valueAccessor());

        var $this = $(element);
        $this.attr('title', value);

        if ($this.data('timeago')) {
          var datetime = $.timeago.datetime($this);
          var distance = (new Date().getTime() - datetime.getTime());
          var inWords = $.timeago.inWords(distance);

          $this.data('timeago', { 'datetime': datetime });
          $this.text(inWords);
        } else {
          $this.timeago();
        }
      }
    };

    init($('#feed_content').data('subject-url'),
      $('#feed_content').data('asker-id'),
      $('#feed_content').data('current_user-id'));
  });
}