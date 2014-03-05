class AddStylesHstoreToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :styles, :hstore

    Asker.all.each do |asker|
      asker.styles = {
        bg_color: asker.bg_color,
        bg_image: asker.bg_image
      }

      asker.save!
    end

    remove_column :users, :bg_color
    remove_column :users, :bg_image
  end

  def self.down
    add_column :users, :bg_color, :string
    add_column :users, :bg_image, :string

    Asker.all.each do |asker|
      asker.update(bg_image: asker.styles['bg_image'])
      asker.update(bg_color: asker.styles['bg_color'])
    end    

    remove_column :users, :styles
  end
end
