module QuestionbaseImporter
  def self.included(base)
      base.extend(ClassMethods)
  end

  module ClassMethods

    require 'net/http'
    require 'uri'

    def qb
      Rails.env.development? ? 'http://localhost:4000' : 'http://questionbase.wisr.com'
    end

    def import_course_from_questionbase course_id, asker_id
      course = get_course course_id
      asker = Asker.find asker_id
      
      course['chapters'].each do |chapter|
        lesson = get_chapter chapter['chapter']['id']
        lesson_topic = Topic.find_or_create_by(
          name: Topic.strip_illegal_chars_from_name(lesson['name']), 
          type_id: 6)

        lesson_topic.askers << asker
        
        lesson['questions'].each do |question|
          find_or_create_question(question['question'], asker_id, lesson_topic)
        end
      end
    end

  private

    def get_course course_id
      url = URI.parse("#{qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_book_details/#{course_id}.json")
      req = Net::HTTP::Get.new(url.path)
      res = Net::HTTP.start(url.host, url.port) { |http| http.request(req) }

      JSON.parse(res.body)
    end

    def get_chapter chapter_id
      url = URI.parse("#{qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_all_lesson_questions/#{chapter_id}.json")
      req = Net::HTTP::Get.new(url.path)
      res = Net::HTTP.start(url.host, url.port) { |http| http.request(req) }
      
      JSON.parse(res.body)
    end

    def find_or_create_question question_hash, asker_id, lesson_topic
      question = Question.find_or_initialize_by(
        questionbase_id: question_hash['id'])

      question.update(
        text: question_hash['question'], 
        created_for_asker_id: asker_id,
        status: 1)

      lesson_topic.questions << question

      find_or_create_answers question, question_hash['answers']
    end

    def find_or_create_answers question, answers_hash
      answers_hash.each do |answer_hash|
        answer = Answer.find_or_initialize_by(
          questionbase_id: answer_hash['answer']['id'])

        answer.update(
          text: answer_hash['answer']['answer'], 
          correct: answer_hash['answer']['correct'],
          question_id: question.id)
      end
    end
  end
end