class RemoveColumnSeederIdFromQuestions < ActiveRecord::Migration
  def change
    remove_column :questions, :seeder_id, :integer
  end
end
