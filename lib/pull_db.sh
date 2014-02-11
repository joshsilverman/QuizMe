#!/bin/bash

function LastBackupName () { 
  heroku pgbackups -a wisr | tail -n 50 | head -3 | tail -n 1 | cut -d" " -f 1
}

heroku pgbackups -a wisr >&2

heroku pgbackups:capture -a wisr >&2
new_backup=$(LastBackupName)
curl $(heroku pgbackups:url -a wisr $new_backup) > temporary_backup.dump

old_backup=$(LastBackupName)
heroku pgbackups:destroy -a wisr $old_backup >&2

pg_restore --verbose --clean --no-acl --no-owner -h localhost -U wisr -d wisr temporary_backup.dump 
rm -f temporary_backup.dump

heroku pgbackups -a wisr >&2