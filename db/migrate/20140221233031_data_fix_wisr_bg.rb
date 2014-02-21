class DataFixWisrBg < ActiveRecord::Migration
  def up
    wisr = Asker.where("twi_screen_name ilike ?", 'wisr').first

    if wisr
      wisr.update bg_image: nil
    end
  end
end
