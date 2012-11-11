require 'csv'

namespace :export do
  task :paulgraham => :environment do
    @paulgraham, pg_display_data = Stat.paulgraham

    CSV.open("tmp/paulgraham.csv", "w") do |csv|
      csv << ["Date", "ratio"]
      @paulgraham.each do |row|
        csv << [row[0], row[1][:raw]]
      end
    end
  end

  task :econ_engine => :environment do
    @econ_engine, econ_engine_display_data = Stat.econ_engine

    CSV.open("tmp/econ_engine.csv", "w") do |csv|
      @econ_engine.each do |row|
        csv << row
      end
    end
  end

  task :daus => :environment do
    @daus, daus_display_data = Stat.daus

    CSV.open("tmp/daus.csv", "w") do |csv|
      @daus.each do |row|
        csv << row
      end
    end
  end

  task :growth => :environment do
    @paulgraham, pg_display_data = Stat.paulgraham nil, 90
    @econ_engine, econ_engine_display_data = Stat.econ_engine nil, 90
    @daus, daus_display_data = Stat.daus nil, 90

    CSV.open("tmp/growth.csv", "w") do |csv|
      csv << ["Date", "ratio"]
      @paulgraham.each do |row|
        csv << [row[0], row[1][:raw]]
      end

      @econ_engine.each do |row|
        csv << row
      end

      @daus.each do |row|
        csv << row
      end
    end
  end
end