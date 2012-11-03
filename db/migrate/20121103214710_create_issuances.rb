class CreateIssuances < ActiveRecord::Migration
  def change
    create_table :issuances do |t|
      t.integer :user_id
      t.integer :badge_id

      t.timestamps
    end
  end
end
