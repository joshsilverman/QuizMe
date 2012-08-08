require 'csv'

task :identify_advanced => :environment do

  CSV.open("advanced.csv", "wb") do |csv|
    csv << ["Username", "Correct Answers", "Total Answered", "Percentage Correct", "Sample Topics"]
    users = User.includes(:reps => [:post => [:question => :topic]])
    users.sort_by! {|u| u.reps.count}

    users.each do |user|
      percentage = (user.reps.where(:correct => true).count.to_f / user.reps.count) if user.reps.count > 0
      percentage ||= 0


      if percentage > 0.6 and user.reps.count > 3
        topics_sample = ''
        (0..2).each {|i| topics_sample += user.reps[i].post.question.topic.name if user.reps[i]}
        puts topics_sample
        
        csv << [user.twi_screen_name, user.reps.where(:correct => true).count, user.reps.count, percentage, topics_sample]
      end
    end
  end
end