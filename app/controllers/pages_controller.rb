class PagesController < ApplicationController

  def sitemap
    data = open("https://s3.amazonaws.com/wisr-sitemap/sitemaps/sitemap.xml.gz") 
    send_data data.read, filename: "sitemap.xml.gz",
      disposition: 'inline', 
      stream: 'true', 
      buffer_size: '4096'
  end
end
