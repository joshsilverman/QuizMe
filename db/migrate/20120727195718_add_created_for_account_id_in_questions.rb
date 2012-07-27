class AddCreatedForAccountIdInQuestions < ActiveRecord::Migration
  def change
    add_column :questions, :created_for_account_id, :integer
  end
end
