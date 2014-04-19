module QuestionbaseImporter
  def self.included(base)
      base.extend(ClassMethods)
  end

  module ClassMethods

    require 'net/http'
    require 'uri'

    # qb = Rails.env.production? ? 'http://questionbase.studyegg.com' : 'http://localhost:3001'
    def qb
      Rails.env.development? ? 'http://localhost:4000' : 'http://questionbase.studyegg.com'
    end

    def import_course_from_questionbase course_id
      url = URI.parse("#{qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_book_details/#{course_id}.json")
      req = Net::HTTP::Get.new(url.path)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      course = JSON.parse(res.body)
      course_topic = Topic.find_or_create_by(name: course['name'], type_id: 5)
      
      course['chapters'].each do |chapter|
        url = URI.parse("#{qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_all_lesson_questions/#{chapter['chapter']['id']}.json")
        req = Net::HTTP::Get.new(url.path)
        binding.pry
        res = Net::HTTP.start(url.host, url.port) {|http|
          http.request(req)
        }
        lesson = JSON.parse(res.body)
        lesson_topic = Topic.find_or_create_by(name: lesson['name'], type_id: 6)
        yt_video_id = lesson['media_url'].split("?v=")[1]
        lesson['questions'].each do |question|
          if question['resources'] and resource = question['resources'].select { |resource| resource['begin'] }.first
            url = "http://www.youtube.com/embed/#{yt_video_id}?start=#{resource['begin']}&end=#{resource['end']}"
            binding.pry
            question = Question.find_by(resource_url: url)
            if question
              question.topics << lesson_topic unless question.topics.include?(lesson_topic)
              question.topics << course_topic unless question.topics.include?(course_topic)
            else
              puts "couldnt find question from URL"
              puts question
              puts "\n\n"
            end
          else
            puts "couldnt find resource for question"
            puts question
            puts "\n\n"          
          end
        end
      end
    end

    def import_video_urls_from_qb
      egg_ids = {13 => 18, 14 => 19, 30 => 22, 28 => 374}

      egg_ids.each do |egg_id, created_for_asker_id|
        egg = Question.get_studyegg_details(egg_id)
        egg['chapters'].each do |ch|
          Question.save_lesson(ch, created_for_asker_id)
        end
      end
    end  

    def get_studyegg_details(egg_id)
      url = URI.parse("#{qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_book_details/#{egg_id}.json")
      req = Net::HTTP::Get.new(url.path)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      begin
        studyegg = JSON.parse(res.body)
      rescue
        studyegg=nil
      end
      return studyegg
    end

    def save_lesson(lesson, created_for_asker_id)
      @lesson_id = lesson['id'].to_i
      if @lesson_id
        questions = Question.get_lesson_questions(@lesson_id)
        return if questions['questions'].nil?
        questions['questions'].each do |imported_q|
          q = Question.find_by(text: Question.clean_and_clip_question(imported_q['question']))
          next if q.nil?
          puts "\n\nid: #{q.id}"
          puts q.text

          resources = imported_q['resources'] || []
          puts resources.count
          resources.each do |r|
            next unless r['media_type'] == "video"
            q.resource_url = "http://www.youtube.com/embed/#{r['url']}?start=#{r['begin']}&end=#{r['end']}"
          end
          q.save
        end
      end
    end

    def get_lesson_questions(lesson_id)
      url = URI.parse("#{qb}/api-V1/JKD673890RTSDFG45FGHJSUY/get_all_lesson_questions/#{lesson_id}.json")
      req = Net::HTTP::Get.new(url.path)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      begin
        studyegg = JSON.parse(res.body)
        puts res.body
      rescue
        studyegg = nil
      end
      return studyegg
    end

    def clean_and_clip_question(quest)
      if quest[0..3].downcase=='true'
        i = quest.downcase.index('false')
        quest = "T\\F: "+ quest[(i+7)..-1]
      end
      clean_text(quest)
    end

    def clean_text(a)
      a.gsub!('<sub>','')
      a.gsub!('</sub>','')
      a.gsub!('<sup>-</sup>','-')
      a.gsub!('<sup>+</sup>','+')
      a.gsub!('<sup>','^')
      a.gsub!('</sup>','')
      a
    end
  end
end