#!/bin/bash

function LastBackupName () { 
  heroku pgbackups -a wisr | tail -n 1 | cut -d" " -f 1
}

heroku pgbackups:capture -a wisr
new_backup=$(LastBackupName)
curl $(heroku pgbackups:url -a wisr $new_backup) > temporary_backup.dump
pg_restore --verbose --clean --no-acl --no-owner -h localhost -U wisr -d wisr temporary_backup.dump 
rm -f temporary_backup.dump