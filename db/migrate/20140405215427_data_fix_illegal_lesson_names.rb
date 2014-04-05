class DataFixIllegalLessonNames < ActiveRecord::Migration
  def up
    illegal_lesson_ids_names = [
      [403, "Types of immune responses: Innate and Adaptive, Humoral vs Cell Mediated"], 
      [382, "Hardy Weinberg Principle"], 
      [394, "Oxidation and Reduction Review From Biological Point of View"], 
      [358, "Chromosomes, Chromatids, Chromatin, etc"], 
      [373, "Krebs, Citric Acid Cycle"], 
      [396, "C4 Photosynthesis"], 
      [393, "Sex Linked Traits"]]

    illegal_lesson_ids_names.each do |id, name|
      lesson = Topic.find_by(id: id)
      lesson.update name: name
    end
  end
end
