class CreateExams < ActiveRecord::Migration
  def change
    create_table :exams do |t|
      t.integer :user_id
      t.string :subject
      t.datetime :date

      t.timestamps
    end
  end
end
