class AddColumnModerationTriggerTypeIdToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :moderation_trigger_type_id, :integer
  end
end
