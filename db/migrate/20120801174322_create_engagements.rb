class CreateEngagements < ActiveRecord::Migration
  def change
    create_table :engagements do |t|
      t.datetime :date
      t.integer :user_id
      t.string :provider
      t.string :engagement_type

      t.timestamps
    end
  end
end
