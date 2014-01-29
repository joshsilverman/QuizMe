class DropTableExams < ActiveRecord::Migration
  def up
    drop_table :exams
  end

  def down
    create_table :exams do |t|
      t.integer :user_id
      t.string :subject
      t.datetime :date

      t.timestamps
    end
  end
end
