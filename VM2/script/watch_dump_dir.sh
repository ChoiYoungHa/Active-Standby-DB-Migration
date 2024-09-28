#!/bin/bash

WATCH_DIR="/home/username/mysql/mysql_dumps"  # 덤프 파일이 저장되는 호스트 디렉토리

# inotifywait를 사용하여 파일 생성 또는 수정 감지
inotifywait -m -e create,modify --format '%f' "$WATCH_DIR" | while read FILENAME
do
  # 특정 덤프 파일의 변경 감지
  if [[ "$FILENAME" == "fisa_database_dump.sql" ]]; then
    echo "Dump file detected or modified: $FILENAME"
    
     # MySQL 덤프 반영 스크립트 호출
    if docker exec -i mysql-mysql-1 /script/db_dump_migration.sh; then
      echo "Dump file applied successfully."
    else
      echo "Failed to apply dump file: $FILENAME"
    fi
  fi
done
