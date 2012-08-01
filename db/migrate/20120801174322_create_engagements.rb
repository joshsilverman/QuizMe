class CreateEngagements < ActiveRecord::Migration
  def change
    create_table :engagements do |t|
      t.string :date
      t.integer :user_id
      t.integer :account_id
      t.integer :mention_id
      t.string :provider
      t.string :engagement_type
      t.boolean :first_engagement

      t.timestamps
    end
  end
end
