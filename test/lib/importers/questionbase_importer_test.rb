require 'test_helper'

describe Question, "#import_course_from_questionbase" do

  let(:asker) { create :asker }

  let(:course) {
    { 'id' => 2,
      'name' => "Beginners Holiday Spanish",
      'icon_url' => "http://localhost:3001/assets/eggs/0.png",
      'chapters' => [
        { 'chapter' => 
          { 'id' => 3,
            'name' => "Beginners Holiday Spanish - Drinks (complete)",
            'question_count' => 10,
            'number' => 1,
            'status' => 3 
          }
        }
      ]
    }
  }

  let(:chapter) {
    { 'name' => "Drinks",
      'media_url' => "http://www.youtube.com/watch?v=",
      'media_duration' => 0,
      'book_name' => "Beginners Holiday Spanish",
      'questions' => [
        { 'question' => 
          { 'id' => 2,
            'question' => "How do you say \"a beer\" in Spanish?",
            'answers' => [
              { 'answer' => { 'id' => 5,  'answer' => "una cerveza",  'correct' => true}},
              { 'answer' => { 'id' => 6,  'answer' => "un café",  'correct' => false}},
              { 'answer' => { 'id' => 7,  'answer' => "un vino tinto",  'correct' => false}},
              { 'answer' => { 'id' => 8,  'answer' => "un vino blanco",  'correct' => false}}
            ],
            'resources' => []
          }
        }
      ]
    }
  }

  it "calls get_course and get_chapter" do
    Question.expects(:get_course).returns course
    Question.expects(:get_chapter).returns chapter

    Question.import_course_from_questionbase 123, asker.id
  end

  it "creates a new question" do
    Question.stubs(:get_course).returns course
    Question.stubs(:get_chapter).returns chapter

    Question.import_course_from_questionbase 123, asker.id

    Question.last.text.must_equal "How do you say \"a beer\" in Spanish?"
  end

  it "wont recreate the same question" do
    Question.stubs(:get_course).returns course
    Question.stubs(:get_chapter).returns chapter

    Question.import_course_from_questionbase 123, asker.id
    Question.import_course_from_questionbase 123, asker.id

    Question.count.must_equal 1
  end

  it "will update question if changes on reimport" do
    Question.stubs(:get_course).returns course
    Question.stubs(:get_chapter).returns chapter
    Question.import_course_from_questionbase 123, asker.id

    modified_chapter = chapter.clone
    modified_chapter['questions'].first['question']['question'] = 'new text'
    Question.stubs(:get_chapter).returns modified_chapter
    Question.import_course_from_questionbase 123, asker.id

    Question.last.text.must_equal "new text"
  end

  it "creates answers" do
    Question.stubs(:get_course).returns course
    Question.stubs(:get_chapter).returns chapter

    Question.import_course_from_questionbase 123, asker.id

    Question.last.answers.count.must_equal 4
    Question.last.answers.first.text.must_equal 'una cerveza'
  end

  it "will update answer if they change on reimport" do
    Question.stubs(:get_course).returns course
    Question.stubs(:get_chapter).returns chapter
    Question.import_course_from_questionbase 123, asker.id

    modified_chapter = chapter.clone
    modified_chapter['questions'].first['question']['answers']
      .first['answer']['answer'] = 'una bebida'
    Question.import_course_from_questionbase 123, asker.id

    Question.last.answers.count.must_equal 4
    Question.last.answers.first.text.must_equal 'una bebida'
  end

  it "will associate question with correct asker, lesson" do
    Question.stubs(:get_course).returns course
    Question.stubs(:get_chapter).returns chapter

    Question.import_course_from_questionbase 123, asker.id

    Question.last.created_for_asker_id.must_equal asker.id

    Topic.lessons.count.must_equal 1
    Topic.lessons.first.askers.first.id.must_equal asker.id

    Topic.lessons.first.questions.count.must_equal 1
    Topic.lessons.first.name.must_equal 'Drinks'
  end

  it "will not associate a question with the same lesson multiple times" do
    Question.stubs(:get_course).returns course
    Question.stubs(:get_chapter).returns chapter

    Question.import_course_from_questionbase 123, asker.id
    Question.import_course_from_questionbase 123, asker.id

    Topic.lessons.count.must_equal 1
    Topic.lessons.first.questions.count.must_equal 1
    Topic.lessons.first.askers.count.must_equal 1
  end
end