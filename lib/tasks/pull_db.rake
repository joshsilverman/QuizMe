task :db_pull => :environment do
  `bash lib/pull_db.sh`
end