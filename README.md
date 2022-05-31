## системные требования
```
# docker --version
Docker version 17.12.1-ce, build 7390fc6
```

## вводная
* `/adm` - клинтская часть админки игры (ExtJS)
* `/app` - приложение (Python/Tornadoweb)
* `/db/init.sh` - скрипт инициализации новой базы
* `/db/schema.sql` - дамп схемы для наката на новую базу (Postgresql)
* `/docker/py` - сборка образа питона
* `/docker/web` - конфиг для nginx
* `/docker/.env` - пременные окружения, логины/пароли
* `/docker/stack.yml` - главнфй конфиг стэка проекта

## сборка образа питона
* нужно сделать 1 раз
* на базе официального образа будет сделан локальный с нужными модулями
```
# docker build ./docker/py -t bubbles_python:2
```

## конфигурация
* все опционально, можно пропустить
* основное в файле `stack.yml`
* имена и пароли `.env`

## создание роя
* нужно сделать 1 раз
* возможно потребуется указать в какой сети (если на хост машине их несколько)
```
# docker swarm init
Swarm initialized: current node (y12kmc4947nvumiipi4l4l8zk) is now a manager.
```

## запуск стека
* имя стека `bbl19`, можно указывать другое
* для каждого стека с разными именами создается отдельная БД
* перезапуск (остановка и запуск) одного и того же стека будет с той же базой
```
# docker stack deploy -c ./docker/stack.yml bbl19
Creating network bbl19_xnet
Creating service bbl19_db
Creating service bbl19_adm
Creating service bbl19_app
Creating service bbl19_web
```

## проверка работы api
* URI `http://127.0.0.1:8080`
* порт можно поменять в `stack.yml`
```
# curl 127.0.0.1:8080/api/ping
{
  "err": null,
  "pong": 1,
  "time": 1522405482
}
```

## админка игры
* в браузере браузер http://localhost:8080/

## админка базы
* простейщий веб интерфейс БД (Adminer)
* в браузере `http://localhost:8081/`
* System: `PostgreSQL`
* Server: `db`
* логин/пароль бери из файла `.env`

## посмотреть сервисы стека
```
# docker stack ls
NAME                SERVICES
bbl19               4
```

## посмотреть список процессов стека
```
# docker stack ps bbl19
ID                  NAME                IMAGE               NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
bqiatrtqdksg        bbl19_web.1         nginx:1.13          deb3                Running             Running 19 seconds ago
09nyxdsrolzo        bbl19_app.1         bubbles_python:2    deb3                Running             Running 19 seconds ago
hn6a6u8wkwro        bbl19_adm.1         adminer:latest      deb3                Running             Running 27 seconds ago
ay0n378lrghk        bbl19_db.1          postgres:10.3       deb3                Running             Running 31 seconds ago
```

## посмотреть лог работы сервиса
```
# docker service logs -f bbl19_db
bbl19_db.1.ay0n378lrghk@deb3    | 2018-03-30 10:17:04.799 UTC [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
bbl19_db.1.ay0n378lrghk@deb3    | 2018-03-30 10:17:04.799 UTC [1] LOG:  listening on IPv6 address "::", port 5432
bbl19_db.1.ay0n378lrghk@deb3    | 2018-03-30 10:17:04.802 UTC [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
bbl19_db.1.ay0n378lrghk@deb3    | 2018-03-30 10:17:04.815 UTC [21] LOG:  database system was shut down at 2018-03-30 10:15:18 UTC
bbl19_db.1.ay0n378lrghk@deb3    | 2018-03-30 10:17:04.837 UTC [1] LOG:  database system is ready to accept connections
```

## выключить стек
* данные БД будут сохранены в томе докера (см `docker volume ls`), имя тома в `stack.yml`
```
# docker stack rm bbl19
Removing service bbl19_adm
Removing service bbl19_app
Removing service bbl19_db
Removing service bbl19_web
Removing network bbl19_xnet
```

## посмотреть список томов
```
# docker volume ls
DRIVER              VOLUME NAME
local               bbl19_bbldata
```
