if ($('.questions-show').length) {
  $(function() {
    var askerId, currentUserId, publicationId, feedPublicationModel,
      questionElmnt;

    function init(subjectUrl, _askerId, _currentUserId, _publicationId) {

      askerId = _askerId;
      currentUserId = _currentUserId;
      publicationId = _publicationId;
      $questionElmnt = $('.questions-show')
      feedPublicationModel = new FeedPublicationModel();
    }

    function FeedPublicationModel() {
      var self = this;
      
      $answersElmnts = $questionElmnt.find('.answer');

      self.id = publicationId;
      self.answered = undefined;

      self.loadAnswers = function() {
        self.answers = [];
        _.each($answersElmnts, function(answerElmnt) {
          var $answerElmnt = $(answerElmnt);
          var attrs = {
            id: parseInt($answerElmnt.attr('answer_id')),
            publication_id: self.id};
          var answer = new AnswerViewModel(attrs, self);

          self.answers.push(answer);
          ko.applyBindings(answer, $answerElmnt[0]);
        });
      }

      self.loadAnswers();
    }

    function AnswerViewModel(attrs, feedPublication) {
      var self = this;

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
        $.post('/respond_to_question', params, self.renderResults);
      }

      self.renderResults = function(status) {
        if (status) {
          self.correct(true);
          $(document).trigger('increment', 'answerCount');
        } else self.incorrect(true);

        self.grading(false);
        self.feedPublication.answered = status;
      }

      self.authenticate = function() {
        window.location.replace("/users/auth/twitter")
      }
    }

    init($('.feed-view').data('subject-url'),
      $('.feed-view').data('asker-id'),
      $('.feed-view').data('current_user-id'),
      $('.questions-show').data('publication-id'));
  });
}