class AddSeederIdToQuestions < ActiveRecord::Migration
  def change
    add_column :questions, :seeder_id, :integer
  end
end
