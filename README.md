# ♟DB서버 이중화 Active, Standby 구축하기

## 🎃 개요
> VM1에서 스프링 서버와 함께 운영중인 Mysql DB 덤프를 2시간마다 추출합니다. 해당 덤프를 VM2의 DB서버로 마이그레이션하는 작업을 자동화 합니다. 운용중인 DB를 매 시간 백업하여 재해상황을 대비합니다.


<br>

## 🥽 작업 Workflow
**1. VM1 MySQL 컨테이너에서 덤프 스크립트를 실행합니다.**<br>
**2. VM1에서 생성한 덤프 파일을 VM2로 전송합니다.**<br>
**3. VM2에서 받은 덤프 파일을 MySQL 컨테이너에 반영하는 스크립트를 작성합니다.**<br>
**4. VM1의 크론탭에 덤프 생성 및 전송, VM2에서 덤프 반영 스크립트를 주기적으로 실행하는 설정을 추가합니다.**


## 🕶 컨테이너와 호스트 Volume Mount
```yaml
services:
  db:
    container_name: mysqldb
    image: mysql:latest
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: [password]
      MYSQL_DATABASE: fisa
      MYSQL_USER: user01
      MYSQL_PASSWORD: [password]
    networks:
      - spring-mysql-net
    healthcheck:
      test: ['CMD-SHELL', 'mysqladmin ping -h 127.0.0.1 -u root --password=$$MYSQL_ROOT_PASSWORD']
      interval: 10s
      timeout: 2s
      retries: 100
    volumes:
      - ./mysql_meta:/var/lib/mysql
      - ./mysql_dumps:/mnt/dumps



  app:
    container_name: springbootapp
    build:
      context: .
      dockerfile: ./Dockerfile
    ports:
      - "8080:8080"
    environment:
      MYSQL_HOST: db
    depends_on:
      db:
        condition: service_healthy
    networks:
      - spring-mysql-net:

networks:
  spring-mysql-net:
    driver: bridge
volumes:
  mysql_meta:
```

<br>
호스트의 mysql_dumps 폴더와 mnt/dumps를 마운트하여 mysql 컨테이너의 덤프파일을 호스트에 전송합니다.
 <br>
 <br>

 ## ⛳ 덤프백업 쉘스크립트 작성
 ```shell
#!/bin/bash

# MySQL 접속 정보
USER="secret"
PASSWORD="secret"
DATABASE="fisa"

# 덤프 파일 경로
DUMP_FILE="/mnt/dumps/mydatabase_dump.sql"  # 마운트된 볼륨 경로

# MySQL 덤프 생성
mysqldump -u $USER -p$PASSWORD $DATABASE > $DUMP_FILE
 ```

**스크립트 컨테이너로 올리기**
```bash
docker cp /script/db_backup.sh mysqldb:/script/db_backup.sh
```


## 🥎 호스트에서 Cron Job 설정


```shell
#!/bin/bash

CONTAINER_NAME="mysql_db"

# 스크립트 실행
docker exec -it $CONTAINER_NAME /script/db_backup.sh

# 덤프 파일 경로
DUMP_FILE="/home/username/test/mysql_dumps/fisa_database_dump.sql"

# VM2 정보
VM2_IP="10.0.2.19"
VM2_USER="username"
VM2_PATH="/home/username/dump"

# SCP를 사용하여 덤프 파일 전송
scp $DUMP_FILE $VM2_USER@$VM2_IP:$VM2_PATH
```


```bash
crontab -e

0 */2 * * * /home/username/test/script/backup_crontab.sh
```
 2시간마다 backup_crontab.sh를 실행하면 컨테이너에서 덤프백업 스크립트가 실행되고 호스트 디렉토리에 덤프파일이 생성됩니다. 그리고 VM2 /home/username/dump 경로에 덤프파일이 전송됩니다. VM1, VM2 통신을 위해 사전에 Virtual box NAT 설정을 해두었습니다.

 ## 🚨 VM1 -> VM2 SCP 전송중 인증 이슈 
**스크립트가 실행될 때마다 scp 명령어 인증에 대한 비밀번호를 입력해주어야 합니다.**
이를 해결하기 위해서 SSH KEY를 생성합니다.
 ```bash
# ssh key 생성
ssh-keygen -t rsa -b 4096

# 공개키 복사
ssh-copy-id username@10.0.2.19
 ```

 ## 🛴 VM1 -> VM2 덤프파일 이관 테스트

**VM1에서 스크립트 실행 시 컨테이너의 덤프파일 호스트로 복제 후 VM2 전송**

![2024-09-28 10 03 24](https://github.com/user-attachments/assets/4a451bb6-7fe0-4780-b746-66c40d1ea223)


**VM2에서 Mysql 덤프파일 확인**

![2024-09-28 10 03 56](https://github.com/user-attachments/assets/805beefa-8353-43b7-bcf8-e0075ed0b38c)
<br>


## 🐳 VM2에서 컨테이너에 덤프 파일 반영

```bash
#!/bin/bash

# MySQL 접속 정보
USER="secret"
PASSWORD="secret"
DATABASE="fisa"
DUMP_FILE="/mnt/dumps/fisa_database_dump.sql"

# MySQL에 덤프 파일 반영
mysql -u $USER -p$PASSWORD $DATABASE < $DUMP_FILE

# 결과 확인
if [ $? -eq 0 ]; then
  echo "Dump file applied success."
else
  echo "Failed to apply dump file."
fi

```

## 🐴VM2 컨테이너에서 스크립트 파일 실행 테스트
![2024-09-28 11 39 11](https://github.com/user-attachments/assets/8d1716b8-d262-4d2d-9dac-28157862b76c)

## 🦏 VM2에서 DUMP 파일 변경감지 후 스크립트 실행
**VM1에서 새로운 dump 파일을 업데이트 해주면 inotify-tools가 이를 감지하고, 덤프를 DB에 새로 반영한다.**
```shell
sudo apt-get install inotify-tools
```
```bash
#!/bin/bash

WATCH_DIR="/home/username/mysql/mysql_dumps"

# inotifywait를 사용하여 파일 생성 또는 수정 감지
inotifywait -m -e create,modify --format '%f' "$WATCH_DIR" | while read FILENAME
do
  # 특정 덤프 파일의 변경 감지
  if [[ "$FILENAME" == "fisa_database_dump.sql" ]]; then
    echo "Dump file detected or modified: $FILENAME"

    # MySQL 덤프 반영 스크립트 호출
    docker exec -it mysql-mysql-1 /script/db_dump_migration.sh

    # 덤프 반영 완료 메시지 출력
    if [ $? -eq 0 ]; then
      echo "Successfully applied dump file: $FILENAME"
    else
      echo "Failed to apply dump file: $FILENAME"
    fi
  fi
done

```
```shell
nohup ./watch_dump_dir.sh &
```
inotify-tools 라이브러리 설치 후 위의 스크립트를 백그라운드로 실행하면 VM1이 전송한 덤프파일이 감지되었을 때 db_dump_migration.sh 스크립트를 실행하여 DB에 새로운 덤프파일을 반영합니다.

## ✨결과
![2024-09-28 13 04 10](https://github.com/user-attachments/assets/6eb25823-bfb6-4394-91a7-527568c2ea70)
![2024-09-28 13 04 56](https://github.com/user-attachments/assets/1fd4eb7d-c340-497c-a8d5-9d5bc5c1edcc)


<br>

1. VM1에서 crontab으로 backup_contab.sh가 실행됩니다.
2. 컨테이너에 있는 db_backup.sh가 실행되면서 DB 덤프를 만들어집니다.
3. 해당 DB 덤프는 호스트와 공유된 volume 폴더에 생깁니다.
4. volume에 있는 덤프파일을 VM2의 컨테이너 volume 위치로 전송합니다.
5. inotify-tools가 VM2 컨테이너의 volume의 변경을 감지합니다.
6. VM2의 mysql 컨테이너에서 스크립트를 실행하여 dump 파일을 db에 반영합니다.


## 🎨고찰
> DB를 이중화하고 Active, Standby로 운영하면서 데이터베이스의 싱크를 맞추기 위해 크론탭으로 배치 마이그레이션을 진행하는 작업을 하였습니다. 사용자가 적거나 사내에서 사용하는 서비스일 경우 데이터의 트랜잭션이 많지 않아서 시간마다 배치를 하는 것이 적합하겠지만 규모가 크고, 대규모 서비스라면 실시간으로 DB를 마이그레이션할 수 있는 방법이 필요할 것이라고 생각합니다.
