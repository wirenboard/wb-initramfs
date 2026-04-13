initramfs для загрузочного образа с USB Mass Storage и USB ether
================================================================

Этот репозиторий переехал из https://github.com/wirenboard/wirenboard,
директория initramfs, ради сборки deb-пакета стандартными пайплайнами.

Пакет wb-initramfs-wbX далее используется при сборке ядра из
https://github.com/wirenboard/linux с соответствующим таргетом (wbX-bootlet).

Порядок работы с образом на производстве
----------------------------------------

После загрузки образа контроллер представляется как USB Mass Storage с
двумя LUN: первый - /dev/mmcblk0, второй - флаг окончания работы с Mass Storage.

 - Загружаем образ прошивки обычным способом (с помощью dd в первый LUN);
 - Записываем произвольный текст во второй LUN (echo '1' > /dev/sdc).

После этого на контроллере отключается USB Mass Storage и он переходит
в режим USB Ethernet. Хост получит IP 192.168.41.2 автоматически через DHCP,
IP контроллера - 192.168.41.1.

Далее с контроллером можно взаимодействовать через ssh, логин root, пароль wirenboard.


Дебианизация
============

Скрипт `make_deb.sh` собирает архив с initramfs (без модулей ядра) и упаковывает его
в deb-пакет. В качестве базового образа rootfs используется соответствующий
файл прошивки (fit) с https://fw-releases.wirenboard.com/.

Этот deb-пакет может быть использован при сборке ядра (zImage) в рамках дебианизации
ядра для использования в бутлетах.

Как загрузиться в бутлет
========================

wb7:
```sh
=> setenv bootargs console=${console} bootmode=debug_console
=> load mmc 1:2 0x42000000 /var/lib/wb-image-update/zImage
=> load mmc 1:2 0x43000000 /boot/dtbs/sun8i-wirenboard720.dtb
=> bootz 0x42000000 - 0x43000000
```

wb8:
```sh
=> setenv bootargs console=${console} bootmode=debug_console
=> load mmc 1:2 0x40080000 /var/lib/wb-image-update/Image.gz
=> load mmc 1:2 0x4FA00000 /boot/dtbs/allwinner/sun50i-h616-wirenboard8xx.dtb
=> booti 0x40080000 - 0x4FA00000
```
