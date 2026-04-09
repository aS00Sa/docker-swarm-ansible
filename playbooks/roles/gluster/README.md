Step-by-Step Deployment GlusterFS (Run on all nodes)

Ubuntu/Debian: sudo apt install glusterfs-server -y.
Fedora/RHEL: yum install glusterfs-server -y.

Start Service: sudo systemctl start glusterd and sudo systemctl enable glusterd.

Prepare Bricks (Run on all nodes)
Format and mount the brick storage:
sudo mkfs.xfs -i size=512 /dev/sdb
sudo mkdir -p /glusterfs/bricks/10.20.10.5
UUID="$(sudo blkid -s UUID -o value /dev/sdb)"
echo "UUID=${UUID} /glusterfs/bricks/10.20.10.5 xfs defaults,nofail 0 0" | sudo tee -a /etc/fstab
sudo mount -a

Проверка дисков и UUID на ноде (как у обычных дисков в fstab):
lsblk -f
sudo blkid /dev/sdX

В Ansible: при `device2_hdd_dev=/dev/sdX` роль сама вызывает `blkid` и монтирует с `UUID=...` в fstab (см. `gluster_brick_fstab_use_uuid`). Явный UUID: `gluster_brick_mount_src: "UUID=...."` в `host_vars`.

Create a subdirectory (brick) for the volume: sudo mkdir -p /glusterfs/bricks/10.20.10.5/gfs
Create the Trusted Storage Pool (Run on Node 1 only)
Probe the other (ALL) nodes to join the cluster:
sudo gluster peer probe 10.20.10.6
sudo gluster peer probe 10.20.10.7

Verify connectivity: sudo gluster peer status.

Create and Start the Volume (Run on Node 1 only)
Create a replicated volume (high availability):
sudo gluster volume create gfs replica 3 \
10.20.10.5:/glusterfs/bricks/10.20.10.5/gfs \
10.20.10.6:/glusterfs/bricks/10.20.10.6/gfs \
10.20.10.7:/glusterfs/bricks/10.20.10.7/gfs force

Start the volume: sudo gluster volume start gfs
Mount the GlusterFS Volume (On Client Nodes)
sudo mkdir -p /mnt/glusterfs
sudo mount -t glusterfs 10.20.10.5:/gfs /mnt/gfs


Основные шаги настройки GlusterFS (Ubuntu):
Подготовка узлов: На всех узлах отредактируйте /etc/hosts, добавив IP-адреса и имена хостов:

sudo nano /etc/hosts
# Добавить: 192.168.10.11 node1, 192.168.10.12 node2

Установка GlusterFS:
sudo apt update
sudo apt install glusterfs-server -y
sudo systemctl start gluster thed && sudo systemctl enable glusterd

Создание пула (на node1):
sudo gluster peer probe node2
sudo gluster peer status

Создание и запуск тома (например, реплика 2):
sudo mkdir -p /data/glusterfs/brick1/gv0
sudo gluster volume create gv0 replica 2 node1:/data/glusterfs/brick1/gv0 node2:/data/glusterfs/brick1/gv0
sudo gluster volume start gv0

Монтирование (клиент):
sudo apt install glusterfs-client
sudo mount -t glusterfs node1:/gv0 /mnt/glusterfs

Удаление (rm) GlusterFS:
Для полного удаления (очистки) тома:
Остановить и удалить том: sudo gluster volume stop gv0 && sudo gluster volume delete gv0
Удалить данные: rm -rf /data/glusterfs/brick1/gv0
Удалить пакеты: sudo apt purge glusterfs-server -y && sudo apt autoremove -y

examples/stack-with-gfs/docker-compose.yml
device: /mnt/gfs/app-data
device: /mnt/gfs/db-data
examples/minio-s3/docker-compose.yml
device: /mnt/gfs/minio-data
examples/nexus-sonatype-swarm/docker-compose.yml
device: /mnt/gfs/nexus-data


Что делать по шагам
Отдельно проверить split-brain (это не то же самое, что heal info):

sudo gluster volume heal gfs info split-brain
Если есть этот путь — дальше только процедура split-brain + выбор source-brick (с бэкапом для БД). Если 0 — остаётесь на обычном heal.

Снизить конкуренцию с Postgres (сильно повышает шанс довести heal):

остановить bethome-postgres (всё, что пишет в этот каталог на GFS);
выполнить:
sudo gluster volume heal gfs
подождать 5–30+ минут, снова:
sudo gluster volume heal gfs info
sudo gluster volume heal gfs statistics
Если долго не сходит:

место на диске на всех трёх кирпичах;
логи: /var/log/glusterfs/ на .5, .6, .7 (ошибки по этому gfid/пути);
при согласовании с админами Gluster — full heal только в окне (тяжёлая нагрузка), синтаксис зависит от версии.
Не править вручную только на .5 или .7: не удалять/не копировать 17585 точечно — риск split-brain и порчи страницы БД.

Смысл в двух словах
Один файл данных Postgres ещё не полностью согласован между репликами; .6 в этом выводе «чистый». Дальше: split-brain check → при 0 — стоп БД + heal gfs + ждать; при не 0 — не лечить «на глаз», нужен явный выбор источника и бэкап.

Пришлите при необходимости свежий heal gfs info split-brain и одну строку heal gfs statistics после остановки Postgres — по ним можно сузить следующий шаг.