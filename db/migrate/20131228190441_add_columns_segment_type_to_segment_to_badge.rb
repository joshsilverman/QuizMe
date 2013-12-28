class AddColumnsSegmentTypeToSegmentToBadge < ActiveRecord::Migration
  def change
    add_column :badges, :segment_type, :integer
    add_column :badges, :to_segment, :integer
  end
end
