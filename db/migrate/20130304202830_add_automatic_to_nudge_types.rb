class AddAutomaticToNudgeTypes < ActiveRecord::Migration
  def change
    add_column :nudge_types, :automatic, :boolean, :default => false
  end
end
