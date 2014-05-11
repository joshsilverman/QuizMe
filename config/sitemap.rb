SitemapGenerator::Sitemap.default_host = "http://www.wisr.com"
SitemapGenerator::Sitemap.sitemaps_host = "http://wisr-sitemap.s3-website-us-east-1.amazonaws.com"
SitemapGenerator::Sitemap.public_path = 'tmp/'
SitemapGenerator::Sitemap.sitemaps_path = 'sitemaps/'
SitemapGenerator::Sitemap.adapter = SitemapGenerator::WaveAdapter.new

SitemapGenerator::Sitemap.create(:create_index => false) do

  # # Generate feed links
  Asker.published.each do |asker|
    add "/#{asker.subject_url}"
  end

  published_asker_ids = Asker.published.pluck :id
  questions = Question.approved.where(created_for_asker_id: published_asker_ids)

  questions.each do |question|
    add "/questions/#{question.id}/#{question.slug}"
  end
end
