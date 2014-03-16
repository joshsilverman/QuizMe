class DataAddBgColors < ActiveRecord::Migration
  def up
    # don't run data migration in test env
    return if Rails.env.test?

    colors = [
      "8f5352", 
      "9470bc", 
      "414948", 
      "d23e3c", 
      "da9e45", 
      "5598b4", 
      "c96558", 
      "af5857", 
      "621e1d", 
      "7c5d31", 
      "54bcaf", 
      "5ae2d1", 
      "27675f"
    ]

    Asker.published.each do |asker|
      bg_color = Paleta::Color.new(:hex, colors.sample)
      bg_color.darken!(bg_color.lightness - 28)
      silhouette_color = bg_color.complement.lighten 24

      styles = asker.styles || {}

      styles['bg_color'] = "##{bg_color.hex}"
      styles['silhouette_color'] = "##{silhouette_color.hex}"

      asker.update styles: {}
      asker.update styles: styles
    end
  end
end
