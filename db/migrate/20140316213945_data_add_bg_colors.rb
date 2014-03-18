class DataAddBgColors < ActiveRecord::Migration
  def up
    # don't run data migration in test env
    return if Rails.env.test?

    colors = {
      'bg_images/nature.svg' => ['#2d0a19', '#9f9263'],
      'bg_images/ww2.svg' => ['#161e3b', '#7d9ff9'],
      'bg_images/village.svg' => ['#4d3522', '#c9b159'],
      'bg_images/city.svg' => ['#342755', '#d17c77'],
      'bg_images/brains.svg' => ['#305565', '#7e8589'],
      'bg_images/tropics.svg' => ['#2d5e58', '#0a2547'],
      'bg_images/england.svg' => ['#0f202a', '#7aa9c7'],
      'bg_images/mountains.svg' => ['#153e61', '#328bd2'],
      'bg_images/people.svg' => ['#521818', '#b57565']
    }

    Asker.published.each do |asker|
      styles = asker.styles || {}
      path = styles['silhouette_image']

      bg_color, silhouette_color = colors[path]
      styles['silhouette_color'] = silhouette_color
      styles['bg_color'] = bg_color

      asker.update styles: {}
      asker.update styles: styles
    end
  end
end
