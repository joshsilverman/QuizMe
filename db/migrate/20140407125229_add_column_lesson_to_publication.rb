class AddColumnLessonToPublication < ActiveRecord::Migration
  def change
    add_column :publications, :_lesson, :hstore
  end
end
