
namespace :questions do
    task :load => :environment do

        require 'csv'
        k = 0
        CSV.foreach("db/questions/govt101.csv") do |row|
          i, question_num , question = row
          answers = row[3,15]

          correct = ''
          incorrect = []
          answers.each do |a|
            if /(.*)\s\(Correct\)$/.match(a)
              correct = a.gsub /\s\(Correct\)$/, ""
            else 
              incorrect << a.gsub(/\s\(Incorrect\)$/, "")
            end
          end

          if question and correct and incorrect.count > 0

            puts "Question #{k}: #{question}"
            puts "Correct: #{correct}"
            incorrect.each_with_index {|aa, i| puts "Incorrect #{i}: #{aa}"}

            q = Question.create(:text => question, :topic_id => 1, :user_id => 1, :status => 1, :created_for_asker_id => 2)
            q.answers << Answer.create(:correct => true, :text => correct)
            incorrect.each {|aa| q.answers << Answer.create(:correct => false, :text => aa)}

          else
            puts "Error!"
            break
          end
          puts ""
          k += 1
        end
    end
end

