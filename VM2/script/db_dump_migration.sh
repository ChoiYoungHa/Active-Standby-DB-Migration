#!/bin/bash

# MySQL 접속 정보
USER="root"
PASSWORD="root"
DATABASE="fisa"
DUMP_FILE="/mnt/dumps/fisa_database_dump.sql"  # 덤프 파일 경로

# MySQL에 덤프 파일 반영
mysql -u $USER -p$PASSWORD $DATABASE < $DUMP_FILE

# 결과 확인
if [ $? -eq 0 ]; then
  echo "Dump file applied success."
else
  echo "Failed to apply dump file."
fi

