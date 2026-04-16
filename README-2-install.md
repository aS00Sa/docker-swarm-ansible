# README 2 - Основной install

## Минимальные требования

- 5 хостов Debian/Ubuntu (обычно: 1 HAProxy/Traefik, 3 managers + 2 workers )
- SSH доступ по ключу (наличие sudo не обязательно)
- Рабочая машина с Windows + wsl или Linux
- отдельный диск одинакового размера на [managers] под Gluster bricks (если необходимо реплики сетевого файлового хранилища держать на отдельном устройстве)

## Подготовка рабочего места перед деплоем

```bash
sudo apt update
sudo apt install -y ansible python3-venv python3-pip

git clone https://github.com/.../docker-swarm-ansible.git
cd docker-swarm-ansible

python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
```

## Проверка доступа

```bash
ansible all -i inventory*.ini -m ping
```

## Основной деплой

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory-dvsprtbt.ini -u root --private-key ~/.ssh/id_ed25519 playbooks/install.yml 2>&1 -vvv | tee inventory-dvsprtbt-$(date +%Y%m%d-%H%M).log
```

Если в WSL `ansible.cfg` игнорируется (каталог под `/mnt/c/...`), всегда задавайте `ANSIBLE_CONFIG="$PWD/ansible.cfg"`.

## Рабочий цикл с логами (без firewall на этапе отладки)

```bash
ANSIBLE_STDOUT_CALLBACK=yaml ANSIBLE_CONFIG="$PWD/ansible.cfg" \
ansible-playbook -i inventory.ini playbooks/install.yml -u root --private-key ~/.ssh/id_ed25519 \
  --skip-tags firewall-iptables -vvv 2>&1 | tee deploy-$(date +%Y%m%d-%H%M).log
```

Потом смотрите лог на `FAILED`, `fatal:`, `ERROR!`.

## Частичные запуски

```bash
ansible-playbook -i inventory.ini playbooks/install.yml --tags haproxy
ansible-playbook -i inventory.ini playbooks/plays/11-haproxy.yml
ansible-playbook -i inventory.ini playbooks/plays/03-firewall-iptables.yml
ansible-playbook -i inventory.ini playbooks/run-role.yml -e target_role=haproxy -e target_hosts=haproxy
```

## Syntax-check

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook -i inventory.ini playbooks/install.yml --syntax-check
```

Что будем запускать





Основной entrypoint: [playbooks/install.yml](playbooks/install.yml) — импортирует все стадии по порядку (plays/01-host-defaults.yml … plays/13-traefik.yml).



Конфиг Ansible: [ansible.cfg](ansible.cfg) задаёт roles_path=playbooks/roles и другие дефолты; inventory по умолчанию ./inventory.ini, поэтому в командах явно указываем ваш inventory-infra-btnxlocal.ini.

Команда «полный прогон, но только новый хост»





Dry-run (рекомендую сначала):

ansible-playbook -i inventory-infra-btnxlocal.ini playbooks/install.yml --limit 188.225.43.161 --check --diff





Реальный прогон:

ansible-playbook -i inventory-infra-btnxlocal.ini playbooks/install.yml --limit 188.225.43.161

На что обратить внимание (важно для --limit)





install.yml включает plays, которые таргетят разные группы. С --limit 188.225.43.161 выполнятся только те задачи, где этот хост попадает в hosts: (например, если он в [haproxy]/[traefik]). Остальные стадии будут просто пропущены.



Если на каком-то этапе окажется, что новой ноде нужно взаимодействовать с уже настроенными менеджерами (например, swarm join), то один --limit может быть недостаточен — тогда корректнее временно расширять лимит на нужные группы (например, --limit '188.225.43.161:swarm_managers'). Это станет видно по ошибкам вида «нужно выполнить действие на manager/leader».

Опциональные ускорители/обходы (если упирается)





Если есть проблемы/долгая отладка с firewall, в install.yml прямо указан вариант:

ansible-playbook -i inventory-infra-btnxlocal.ini playbooks/install.yml --limit 188.225.43.161 --skip-tags firewall-iptables

Мини-проверка перед прогоном





Убедиться, что SSH-ключ из inventory доступен с вашей машины (ansible_ssh_private_key_file=~/.ssh/id_ed25519) и что на хосте есть Python3 (в ansible.cfg задан ansible_python_interpreter=/usr/bin/python3).

Остановить MinIO (и всё, что пишет в этот путь)
Иначе будет постоянная гонка и новые ошибки.

Проверить, как смонтирован /mnt/gfs на ноде

findmnt /mnt/gfs
mount | grep /mnt/gfs
(У вас ранее был конфликт glusterfs и nfs4 на один mountpoint — это надо исключить.)

Проверить состояние Gluster

gluster volume status gfs detail
gluster volume heal gfs info
gluster volume heal gfs statistics
Посмотреть системные/Gluster ошибки в момент I/O

dmesg -T | tail -n 100
tail -n 200 /var/log/glusterfs/bricks/*gfs*.log
tail -n 200 /var/log/glusterfs/glfsheal-*.log
Если mount «подвис» — перемонтировать клиентский /mnt/gfs (после остановки сервисов, использующих путь)

umount /mnt/gfs || umount -l /mnt/gfs
mount /mnt/gfs

Причина прямо в приглашении: вы сейчас стоите в /mnt/gfs (root@n01...:/mnt/gfs#), поэтому mountpoint занят вашим же shell.

Сделайте так:

cd /
umount /mnt/gfs || umount -l /mnt/gfs
Если после cd / всё равно target is busy, найдите держателей:

lsof +f -- /mnt/gfs 2>/dev/null
fuser -vm /mnt/gfs
Обычно держат процессы Docker/контейнеры. Тогда сначала остановить сервисы/стеки, которые используют /mnt/gfs, и повторить umount.


Порядок действий
Выйдите из mc, все shell переведите из /mnt/gfs:
cd /
exit   # в лишних SSH-сессиях
Убедитесь, что держателей стало мало:
sudo fuser -vmM /mnt/gfs
Если остались user-space процессы (mc, bash, контейнеры), мягко завершите:
sudo kill -TERM <pid>
sleep 2
sudo kill -KILL <pid>   # только если не ушёл
Размонтирование:
sudo umount /mnt/gfs || sudo fusermount3 -uz /mnt/gfs || sudo umount -l /mnt/gfs
Проверка:
mount | grep /mnt/gfs
findmnt /mnt/gfs


Отлично — это значит, что /mnt/gfs уже размонтирован (поэтому fuser и пишет, что это не mountpoint).

Дальше проверьте и поднимите монтирование заново:

mount | grep /mnt/gfs
findmnt /mnt/gfs
Если пусто — монтируем:

mount /mnt/gfs
# или явно:
# mount -t glusterfs 10.20.10.6:/gfs /mnt/gfs
Проверка после монтирования:

findmnt /mnt/gfs
ls -la /mnt/gfs
И важный момент: в fstab оставьте только один тип для /mnt/gfs (либо glusterfs, либо nfs4), иначе снова будут конфликт и «залипания».


Если хотите пересоздать gfs с нуля
На первой ноде (если том еще существует):

gluster volume stop gfs force
gluster volume delete gfs

1. Посмотреть, что вообще знает кластер
На любой ноде (лучше на 10.20.10.5):

gluster volume list
gluster volume info gfs
gluster peer status
Если volume list не показывает gfs, а только delete ругается на lock — это чисто мусорные метаданные.

2. Проверка/перезапуск glusterd на 10.20.10.6
На 10.20.10.6:

systemctl status glusterd
journalctl -u glusterd -n 50
Если там всё ок — сделайте мягкий рестарт:

systemctl restart glusterd
Потом с 10.20.10.5 ещё раз:

gluster peer status
gluster volume delete gfs
Часто уже после рестарта lock пропадает и delete спокойно говорит, что тома нет.

3. Если volume list пуст по gfs, но delete всё равно ноет
Это значит, что тома уже нет, можно переходить к ручной очистке:

На КАЖДОЙ brick-ноде (5, 6, 7):

mkdir -p /glusterfs/bricks/10.20.10.X/gfs
find /glusterfs/bricks/10.20.10.X/gfs -mindepth 1 -delete
ls -la /glusterfs/bricks/10.20.10.X/gfs
(подставьте X соответствующий IP ноды; после ls должны быть только . и ..).

4. После очистки — создание нового тома
Либо:

gluster volume create gfs replica 3 \
  10.20.10.5:/glusterfs/bricks/10.20.10.5/gfs \
  10.20.10.6:/glusterfs/bricks/10.20.10.6/gfs \
  10.20.10.7:/glusterfs/bricks/10.20.10.7/gfs force
gluster volume start gfs
либо тем же плейбуком 07-gluster.yml (как только SSH с Ansible вы настроите).

Если покажете вывод gluster volume list и gluster peer status, скажу, нужно ли ещё чистить метаданные на 10.20.10.6 (в /var/lib/glusterd/vols/gfs) или достаточно рестарта glusterd.


1. Посмотреть, что вообще знает кластер
На любой ноде (лучше на 10.20.10.5):

gluster volume list
gluster volume info gfs
gluster peer status
Если volume list не показывает gfs, а только delete ругается на lock — это чисто мусорные метаданные.

2. Проверка/перезапуск glusterd на 10.20.10.6
На 10.20.10.6:

systemctl status glusterd
journalctl -u glusterd -n 50
Если там всё ок — сделайте мягкий рестарт:

systemctl restart glusterd
Потом с 10.20.10.5 ещё раз:

gluster peer status
gluster volume delete gfs
Часто уже после рестарта lock пропадает и delete спокойно говорит, что тома нет.

3. Если volume list пуст по gfs, но delete всё равно ноет
Это значит, что тома уже нет, можно переходить к ручной очистке:

На КАЖДОЙ brick-ноде (5, 6, 7):

mkdir -p /glusterfs/bricks/10.20.10.X/gfs
find /glusterfs/bricks/10.20.10.X/gfs -mindepth 1 -delete
ls -la /glusterfs/bricks/10.20.10.X/gfs
(подставьте X соответствующий IP ноды; после ls должны быть только . и ..).

4. После очистки — создание нового тома
Либо:

gluster volume create gfs replica 3 \
  10.20.10.5:/glusterfs/bricks/10.20.10.5/gfs \
  10.20.10.6:/glusterfs/bricks/10.20.10.6/gfs \
  10.20.10.7:/glusterfs/bricks/10.20.10.7/gfs force
gluster volume start gfs
либо тем же плейбуком 07-gluster.yml (как только SSH с Ansible вы настроите).

Если покажете вывод gluster volume list и gluster peer status, скажу, нужно ли ещё чистить метаданные на 10.20.10.6 (в /var/lib/glusterd/vols/gfs) или достаточно рестарта glusterd.

Сначала важно: detach/peer-ы делают только когда томов уже нет (или вы точно понимаете, что их уничтожаете). У вас gfs уже «убит», так что можно.

1. Проверить текущее состояние кластера
На любой ноде (обычно 10.20.10.5):

gluster volume list
gluster peer status
Убедитесь, что нет живых томов, которые жалко.

2. Отцепить все peer-ы (разорвать кластер)
На 10.20.10.5:

gluster peer detach 10.20.10.6
gluster peer detach 10.20.10.7
При необходимости повторите с других нод (если какая-то считает других «живыми»):

# на 10.20.10.6
gluster peer detach 10.20.10.5
gluster peer detach 10.20.10.7
# на 10.20.10.7
gluster peer detach 10.20.10.5
gluster peer detach 10.20.10.6
После этого на каждой ноде:

gluster peer status
Должно быть либо пусто, либо только «localhost».

3. (Опционально) перезапустить glusterd
На всех трёх:

systemctl restart glusterd
И снова gluster peer status на одной ноде.

4. Создать peers заново
На одной ноде (например 10.20.10.5), при условии что /etc/hosts / DNS между ними настроен:

gluster peer probe 10.20.10.6
gluster peer probe 10.20.10.7
Потом проверить:

gluster peer status
Все три IP должны быть в состоянии Peer in Cluster.

5. После этого — заново создать том

# каталоги bricks должны быть пустыми:
# /glusterfs/bricks/10.20.10.X/gfs на всех трёх
gluster volume create gfs replica 3 \
  10.20.10.5:/glusterfs/bricks/10.20.10.5/gfs \
  10.20.10.6:/glusterfs/bricks/10.20.10.6/gfs \
  10.20.10.7:/glusterfs/bricks/10.20.10.7/gfs force
gluster volume start gfs
gluster volume info gfs
Если где‑то команда peer detach не проходит или peer status показывает «не в cluster», скиньте именно этот вывод — подкорректируем шаги.

Пиры сейчас в идеале: на всех трёх нодах State: Peer in Cluster (Connected) — значит кластер живой, пересоздавать peer-ы не нужно.

Дальше для нового тома gfs делаем только две вещи:

1. Очистить brick-каталоги на всех трёх нодах
На 10.20.10.5:

mkdir -p /glusterfs/bricks/10.20.10.5/gfs
find /glusterfs/bricks/10.20.10.5/gfs -mindepth 1 -delete
ls -la /glusterfs/bricks/10.20.10.5/gfs
На 10.20.10.6:

mkdir -p /glusterfs/bricks/10.20.10.6/gfs
find /glusterfs/bricks/10.20.10.6/gfs -mindepth 1 -delete
ls -la /glusterfs/bricks/10.20.10.6/gfs
На 10.20.10.7:

mkdir -p /glusterfs/bricks/10.20.10.7/gfs
find /glusterfs/bricks/10.20.10.7/gfs -mindepth 1 -delete
ls -la /glusterfs/bricks/10.20.10.7/gfs
В ls должно остаться только . и ...

2. Создать и запустить новый том gfs
На любой одной ноде (обычно 10.20.10.5):


gluster volume create gfs replica 3 \
  10.20.10.5:/glusterfs/bricks/10.20.10.5/gfs \
  10.20.10.6:/glusterfs/bricks/10.20.10.6/gfs \
  10.20.10.7:/glusterfs/bricks/10.20.10.7/gfs force
gluster volume start gfs
gluster volume info gfs
Если create или start выдаст ошибку — пришлите её текст целиком, разберём точечно.

1. Подготовка (на всех трёх: 10.20.10.5–7)
Остановите сервисы, которые пишут в /mnt/gfs (Docker-стеки и т.д.).
При необходимости размонтируйте клиентский том: cd / && umount /mnt/gfs (или umount -l).
Пиры у вас уже Connected — заново peer probe не нужен.

2. Удалить старый том gfs (если ещё виден в кластере)
На одной ноде:

gluster volume list
Если gfs есть:

gluster volume stop gfs force
gluster volume delete gfs
Если delete снова даст lock на .6 — на 10.20.10.6: systemctl restart glusterd, повторить delete.

3. Очистить brick-каталоги под роль Ansible (на каждой ноде)
mkdir -p /glusterfs/bricks/10.20.10.X/brick
find /glusterfs/bricks/10.20.10.X/brick -mindepth 1 -delete
ls -la /glusterfs/bricks/10.20.10.X/brick
(X — 5, 6, 7; в ls только . и ...)

Опционально, если остались хвосты от старой схемы:

rm -rf /glusterfs/bricks/10.20.10.X/gfs
4. Запуск Ansible с inventory-sprtbt.ini
С машины, где есть ansible-playbook и SSH к мастерам:


ansible-playbook -i inventory-sprtbt.ini playbooks/plays/07-gluster.yml
При необходимости укажите пользователя и ключ, как у вас принято, например:

ansible-playbook -i inventory-sprtbt.ini playbooks/plays/07-gluster.yml -u root --private-key ~/.ssh/id_ed25519
Плейбук 07-gluster.yml для вашего контура по сути делает только первый play на gluster_nodes_bricks (второй play — отдельный том для cert-manager, у вас cert_manager_use_shared_storage=false, он не трогает основной gfs).

5. Проверка на ноде
gluster volume info gfs
mount | grep /mnt/gfs
ls /mnt/gfs
Про inventory-sprtbt.ini: переменные Gluster заданы и в [gluster_nodes:vars], и в [all:vars] — дублируют друг друга, но значения совпадают (device2_hdd_dev="", локальная ФС). Можно позже оставить только в [gluster_nodes:vars], чтобы не путаться.

Если пришлёте вывод gluster volume list после шага 2 и ошибку ansible-playbook (если будет), можно сузить следующий шаг.

