Розбір інциденту (Post-Mortem)
Каскадний збій інфраструктури – 22 червня 2026 р.
# Метадані
| Поле | Значення |
| --- | --- |
| Назва інциденту | Каскадний збій: Synology NAS, DC01, vCenter SSL, Kubernetes etcd |
| Дата інциденту | 19 червня 2026 р. |
| Рівень критичності | SEV-1 - повна недоступність ключових сервісів |
| Тривалість простою | ~56 год (від виявлення ~16:30 пт. до відновлення ~12:00 пн) |


# 1. Стислий опис (TL;DR)
Ввечері 19 червня у серверній стався перебій живлення; один з ДБЖ відмовив, що призвело до некоректного вимкнення Synology NAS і кількох ESXi хостів. Ранком адміністратор виявив, що один сервер не запускається через несправний ДБЖ, а Synology NAS перейшов у read-only режим через пошкодження ext4-файлової системи. Оскільки NFS-сховище стало недоступним на запис, по ланцюгу відмовили: DC01 (домен-контролер), vCenter Server (одночасно виявлено прострочений SSL-сертифікат) та Kubernetes etcd (boltdb-корупція через аварійне вимкнення). Загальний час від виявлення до повного відновлення склав ~56 годин; стан etcd не вдалось відновити з backup (backup-и не існували), тому кластер відновлено через force-new-cluster з утратою стану Kubernetes-об'єктів.
# 2. Вплив
- Synology NAS (NFS-Storage): read-only ~54 год. (16:30 пт. – 10:40 пн.). Усі VM на NFS-сховищі не могли виконувати запис.
- DC01 (Domain Controller VM): недоступний ~54 год. (16:30–10:40). Автентифікація Active Directory деградована.
- vCenter Server: недоступний ~55 год (16:30–11:40). Управління vSphere VM через GUI неможливе.
- Kubernetes API (etcd): недоступний ~56 год (16:30–12:00). Усі K8s-сервіси не відповідали.
- K8s workloads (Deployments, Services, ConfigMaps тощо): ВТРАЧЕНО стан після force-new-cluster. Потребують повторного застосування з GitOps.
- Дані VM на NFS: збережені (fsck виправив помилки, дані не видалено).
- Постраждалі: всі сервіси навчальної лабораторії IST VITI, що залежать від K8s або AD.

# 3. Хронологія подій (EEST, UTC+3)
| Час | Подія |
| --- | --- |
| Вечір 16:30
19 червня | Перебої в живленні серверної. Один з ДБЖ виходить з ладу. Synology NAS та ESXi хости отримують аварійне вимкнення. |
| Ранок 08:50 
22 червня | Дмитро Білашко приходить до серверної. Виявлено: один ESXi хост не запускається - підключений до несправного ДБЖ. Спроба запустити DC01 на pve1 закінчилась помилкою «Transport (VMDB) error -45» - NFS volume у read-only. |
| ~09:10 | Хост pve3 переключено на справний ДБЖ. ESXi завантажується. Виявлено «Danger» alert на Synology DSM - storage pool пошкоджено. |
| ~09:20 | Перша спроба запустити DC01 на pve3: «Transport (VMDB) error -45» - NFS volume у read-only. |
| ~09:50 | DC02 автоматично стартує після повного ребуту ESXi (NFS досі в ro-режимі, але vmx відкрився з кешу).
DC01 так і не запускається з тією ж помилкою.
Процес, який відповідав за  запуск DHCP-серверу не запустився. DHCP сервер на DC02 не був авторизований |
| ~10:15 | vSphere Manager перестає відповідати - «SSL certificate verify failed». vCenter SSL прострочений (незалежна проблема). |
| ~10:30 | Початок діагностики Synology: SSH, df -h, mount - volume_2 ro,norecovery. mdadm, lvdisplay - RAID і LVM здорові. |
| ~10:40 | fsck.ext4 -y завершено - «FILE SYSTEM WAS MODIFIED». Synology перезавантажено через DSM. |
| ~10:40 | Процес, що відповідає за DHCP-сервер на DC02 був перезапущений, DHCP-сервер на DC02 в роботі. Доступ до інтернету відновлено. |
| ~10:50 | Synology online, NFS r/w. DC01 підтверджена як running (esxcli vm process list). Зайва спроба Power On скасована. DHCP-сервер на DC01 знову в роботі. |
| ~11:00 | Старт відновлення vCenter SSL: GRUB-меню не з'являється - додано bios.bootDelay=10000 до vmx через esxi pve3 GUI в Edit Settings VM. |
| ~11:05 | GRUB edit mode: linux /$photon_linux rw init=/bin/bash → passwd root → reboot. Root-пароль скинуто, через відсутність паролю до vSphere Manager в сховищах паролів. |
| ~11:10 | certificate-manager option 8 (Reset all certificates), VMCA Name=CA. vCenter VMCA перевидано. vSphere Manager доступний. |
| ~11:15 | Виявлено: kube-apiserver та etcd не запущені. crictl logs etcd: «panic: freepages: multiple references for pgid». |
| ~11:25 | Спроба bbolt surgery freelist abandon - виконалась, але etcd все одно панікував (несумісність bbolt v1.5.0 / etcd v1.3.10). |
| ~11:35 | bbolt rebuild - panic. etcdutl - відсутній. Бекапів etcd немає. Прийнято рішення: force-new-cluster. |
| ~11:40 | etcd force-new-cluster запущено. kubectl get nodes - Forbidden (kubeadm 1.29+: group kubeadm:cluster-admins). |
| ~11:55 | super-admin.conf + ClusterRoleBinding для kubeadm:cluster-admins - kubectl доступний. Кластер відновлено. |
| ~12:00 | Усі компоненти online. Розпочато re-apply GitOps workloads та rejoin worker-нод. Інцидент закрито. |


# 4. Виявлення
Інцидент виявлено ВРУЧНУ – Дмитром Білашком, який прийшов до серверної зранку. Жодного автоматичного сповіщення не надійшло: система моніторингу зі сповіщеннями в інфраструктурі відсутня. Між початком інциденту (аварійне вимкнення вночі) та виявленням минуло кілька годин. Якби адміністратор не з'явився вранці або перебій стався у вихідний – простій міг тривати значно довше.
Окремо: vCenter SSL-сертифікат закінчився ще до інциденту, але через відсутність моніторингу це не було виявлено завчасно.

# 5. Першопричина (метод «5 чому»)
Ланцюжок першопричин:
Kubernetes, DC01 та vCenter були недоступні.  Чому?
Synology NAS NFS-сховище перейшло у read-only режим, заблокувавши запис для всіх залежних сервісів.
Чому NAS перейшов у read-only?
DSM виявив критичні помилки в ext4 файловій системі на volume_2 та примусово перемонтував його у захисний режим.
Чому виникли помилки ext4?
Synology NAS був аварійно вимкнений під час перебою живлення - ДБЖ, до якого він був підключений, перестав працювати.
Чому відмова ДБЖ не була виявлена до інциденту?
Відсутній моніторинг інфраструктури зі сповіщеннями. Стан ДБЖ, SMART-диски, здоров'я FS - ніщо не відстежувалося автоматично.
Чому відсутній моніторинг?
Система моніторингу (Prometheus/Alertmanager або аналог) не була розгорнута
Додаткова незалежна причина (vCenter SSL):
1. vCenter SSL-сертифікат закінчився без жодного попередження. Чому?
1. Алертів на expiry немає, auto-renewal не налаштовано, дата закінчення ніким не відстежувалась.
Додаткова незалежна причина (etcd):
1. etcd розміщено на NFS (~200ms latency - поза специфікацією etcd <10ms). Бекапів etcd не існувало. При аварійному вимкненні boltdb отримав корапцію freelist-сторінок, яка не піддалась виправленню через несумісність версій bbolt.
Першопричина системного рівня: відсутність моніторингу зі сповіщеннями призвела до  несвоєчасної реакції. Відмова ДБЖ, деградація FS, закінчення SSL-сертифіката – усі ці події могли бути виявлені автоматично задовго до того, як перетворились на критичний збій.

# 6. Усунення та відновлення
## Synology NAS - ext4 fsck
- umount /dev/vg1/volume_2 → fsck.ext4 -y → FILE SYSTEM WAS MODIFIED → Synology reboot через DSM
- Результат: volume_2 змонтований r/w, NFS-Storage доступний
## ESXi хост (несправний ДБЖ)
- Сервер фізично переключено до справного ДБЖ → хост завантажився штатно
- Workaround: жоден постійний захист не впроваджено (тимчасово)
## DC01 - каскад NFS-lock + haTask
- vim-cmd vimsvc/task_cancel <task-id> → скасовано застряглу haTask
- На pve1: kill <vmx-world-id> + rm stale .vswp файлів → NFS-lock знятий
- /etc/init.d/hostd restart на ESXi
- esxcli vm process list підтвердив DC01 running з 07:47 - повторний Power On не потрібен
## vCenter - прострочений SSL
- GRUB: bios.bootDelay=10000 → edit mode → linux rw init=/bin/bash → passwd root
- /usr/lib/vmware-vmca/bin/certificate-manager → option 8 → VMCA Name: CA
- Постійне виправлення: сертифікати перевидано; тимчасового обхідного шляху не застосовано
## Kubernetes etcd - boltdb corruption
- bbolt surgery freelist abandon - не допомогло (несумісність v1.5.0 vs v1.3.10)
- bbolt surgery freelist rebuild - panic (критична b-tree корупція)
- etcdutl - відсутній; .snap.db файлу немає; бекапів немає
Постійне виправлення (з утратою стану):
- mv /var/lib/etcd/member → member.corrupt; --force-new-cluster → etcd запущено
- super-admin.conf + kubectl create clusterrolebinding kubeadm-cluster-admins --clusterrole=cluster-admin --group=kubeadm:cluster-admins
- Додано Ansible: etcd-backup.sh + systemd timer (щодня 02:00, 7-денне утримання) + etcd-recovery.yml playbook

# 7. Аналіз: що було добре / погано / де пощастило
## Що спрацювало добре
- Всі дані VM на NFS збереглись - fsck виправив FS, не знищив дані
- journalctl та crictl logs швидко вказали на etcd як причину недоступності K8s API
- bbolt та etcdctl були встановлені в процесі і стали частиною Ansible-ролі для майбутніх інцидентів
- GitOps (k8s-apps, k8s-terraform) зберіг стан конфігурації - K8s workloads можна відновити re-apply
## Що пішло не так / було складно
- Про інцидент дізналися ВРУЧНУ – ніякого моніторингу/алертів
- Відмова ДБЖ не була помічена до того, як спричинила збій
- Root-пароль vCenter не був задокументований – потрібен GRUB reset
- etcd на NFS без бекапів – при корапції єдиний вихід: force-new-cluster (втрата стану)
- bbolt surgery витратила ~30 хвилин через несумісність версій - не задокументовано в runbook
- vCenter SSL закінчився без будь-якого попередження
- haTask -18 в ESXi заблокувала всі операції - потрібен hostd restart (не очевидно)
- kubeadm 1.29+ змінив RBAC group на kubeadm:cluster-admins - kubectl Forbidden після force-new-cluster
## Де нам пощастило
- Дані VM залишились цілими – якби fsck не допоміг, втрати були б значно більшими(4Тб даних)
- Synology RAID (md0/md1/md2) залишився здоровим – проблема тільки в ext4 поверх LVM
- GitOps-репо зберегло весь стан K8s конфігурації, тому force-new-cluster не означає «все з нуля»
- На pve3 зберігся SSH-доступ, що дозволило редагувати vmx vCenter без vSphere GUI

# 8. План дій (Action Items)
| # | Дія | Відповідальний |
| --- | --- | --- |
| 1 | Розгорнути Prometheus + Alertmanager з алертами: UPS статус (NUT/SNMP), Synology FS errors, SSL cert expiry <30 днів, etcd health, K8s node NotReady | Даніл Жигір |
| 2 | Налаштувати graceful shutdown Synology та ESXi хостів при спрацюванні ДБЖ (NUT daemon або IPMI shutdown-скрипт) | Завіруха Кирило |
| 3 | Перевірити та замінити несправний ДБЖ; впровадити квартальне тестування всіх ДБЖ | ? |
| 4 | Запустити site.yml на k8s-master-01 для активації etcd-backup.timer; перевірити перший snapshot в /var/backups/etcd/ | Завіруха Кирило |
| 5 | Rejoin k8s-worker-01..04 до кластера; запустити k8s-apps GitOps pipeline для re-apply всіх workloads | Завіруха Кирило |
| 6 | Мігрувати etcd data dir з NFS на локальний SSD k8s-master-01 (поточна latency ~200ms - поза spec etcd <10ms) | Завіруха Кирило |
| 7 | Зберегти root-паролі всіх критичних VM (vCenter, ESXi, Synology) у HashiCorp Vault або Password Manager | Дмитро Білашко |
| 8 | Налаштувати автоматичне відстеження та renewal SSL-сертифіката vCenter (alert за 30 і 7 днів до expiry) | Євгеній Костюк |
| 9 | Написати runbook docs/runbooks/ для: vCenter cert reset, etcd recovery (bbolt surgery + force-new-cluster + RBAC fix), ESXi haTask cancel | Даніл Жигір |
| 10 | Додати etcdutl до master Ansible role або зберігати окремий backup-контейнер etcd для відновлення snapshot | Денис Артемасов |


# 9. Здобуті уроки
Цей інцидент показав, що окремі технічні проблеми (перебій живлення, FS-корапція, прострочений сертифікат) самі по собі були б вирішені за 30–60 хвилин. Катастрофою їх зробила відсутність трьох речей: моніторингу (ніхто не знав про проблеми до того, як вони накопичились), захисту від аварійного вимкнення (ДБЖ, graceful shutdown), та задокументованих процедур відновлення з готовими інструментами й бекапами.
Найдорожчою помилкою виявилась відсутність бекапів etcd. «etcd живе на NFS, NFS завжди доступний» - хибна логіка: саме NFS і став точкою відмови. Дані Kubernetes-кластера втрачено повністю; відновлення можливе лише тому, що конфігурація зберігалась у GitOps-репозиторіях.
Документ складено: 23 червня 2026 р.