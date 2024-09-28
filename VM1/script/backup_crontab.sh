#!/bin/bash

CONTAINER_NAME="mysqldb"

# 스크립트 실행
docker exec -it $CONTAINER_NAME /script/db_backup.sh

DUMP_FILE="/home/username/test/mysql_dumps/fisa_database_dump.sql"

VM2_IP="10.0.2.19"
VM2_USER="username"
VM2_PATH="/home/username/mysql/mysql_dumps"

scp $DUMP_FILE $VM2_USER@$VM2_IP:$VM2_PATH
