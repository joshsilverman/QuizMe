class CreateRatings < ActiveRecord::Migration
  def change
    create_table :ratings do |t|
      t.references :user, index: true
      t.references :question, index: true
      t.integer :score

      t.timestamps
    end
  end
end
