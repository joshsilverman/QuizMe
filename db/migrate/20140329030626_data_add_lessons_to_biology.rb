class DataAddLessonsToBiology < ActiveRecord::Migration
  def up
    bio = Asker.where(id: 18).first
    return if !bio

    Topic.lessons.each do |lesson|
      next if lesson.askers.count > 0

      lesson.askers << bio
    end
  end
end
