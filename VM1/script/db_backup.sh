#!/bin/bash

USER="root"
PASSWORD="root"
DATABASE="fisa"

DUMP_FILE="/mnt/dumps/fisa_database_dump.sql"  # 마운트된 볼륨 경로

# MySQL 덤프 생성
mysqldump -u $USER -p$PASSWORD $DATABASE > $DUMP_FILE
