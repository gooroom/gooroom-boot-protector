#!/bin/bash

#
# Copyright (C) 2017~2022 jongkyung.woo <jkwoo@gooroom.kr>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

if [ $# -eq 0 ]; then
    KEY_PATH=.
else
    ## KEY_PATH check
    if [ ! -e $1 ]; then
        echo -e  ">>>There is not $1 (KEY_PATH) directory."; exit 1;
    fi
    KEY_PATH=$1
fi


#
## Install Packages
#

pkgs=(
efitools
sbsigntool
gnupg
gooroom-grub-common
gooroom-grub-efi-amd64-bin
)

for pkg in "${pkgs[@]}"; do
  dpkg -l | grep $pkg >/dev/null 2>&1

  if [ $? -ne 0 ]; then
    echo ">>> $pkg installation....."

    apt install $pkg
      if [ $? -ne 0 ]; then
        echo -e ">>> $pkg is not found ..."; exit;
      fi
  else
    echo -e "### $pkg installation already done."
  fi
done

GRUBX64=./grubx64.efi
GRUBCFG=./grub.cfg

GPG_KEY_FILE=$KEY_PATH/gooroom-3.0-secret-key.gpg
BOOT_KEY_FILE=/etc/apt/trusted.gpg.d/gooroom-archive-3.0.gpg
#BOOT_KEY_FILE=$KEY_PATH/boot.key

#
## Create PK.auth, KEK.auth and db.auth
#  - Key archving target : db.crt db.key
#

if [ ! -e ${KEY_PATH}/db.key -o ! -e ${KEY_PATH}/db.crt ]; then
    echo -e "=============================================================="
    echo -e "### The ${KEY_PATH}/db.key or ${KEY_PATH}/db.crt is not exists"
    echo -e "# Generating the PK.auth KEK.auth db.auth"
    echo -e "=============================================================="

    rm -rf KEK.auth KEK.cer KEK.crt KEK.esl KEK.key \
            PK.auth  PK.cer  PK.crt  PK.esl  PK.key \
            db.auth  db.cer          db.esl
           #db.auth  db.cer  db.crt  db.esl  db.key

    # Create PK.auth
    echo -e ">>> create ${KEY_PATH}/PK.auth"
    openssl req -new -x509 -newkey rsa:2048 -subj "/CN=my PK/" \
	        -keyout PK.key -out PK.crt -days 3650 -nodes -sha256
    openssl x509 -outform DER -in PK.crt -out ${KEY_PATH}/PK.cer
    cert-to-efi-sig-list -g `uuidgen` PK.crt PK.esl
    sign-efi-sig-list -k PK.key -c PK.crt PK PK.esl ${KEY_PATH}/PK.auth

    # Create KEK.auth
    echo -e ">>> create ${KEY_PATH}/KEK.auth"
    openssl req -new -x509 -newkey rsa:2048 -subj "/CN=my KEK/" \
	        -keyout KEK.key -out KEK.crt -days 3650 -nodes -sha256
    openssl x509 -outform DER -in KEK.crt -out ${KEY_PATH}/KEK.cer
    cert-to-efi-sig-list -g `uuidgen` KEK.crt KEK.esl
    sign-efi-sig-list -k PK.key -c PK.crt KEK KEK.esl ${KEY_PATH}/KEK.auth

    # Create db.auth
    echo -e ">>> create ${KEY_PATH}/db.auth"
    openssl req -new -x509 -newkey rsa:2048 -subj "/CN=my db/" \
	        -keyout ${KEY_PATH}/db.key -out ${KEY_PATH}/db.crt -days 3650 -nodes -sha256
    openssl x509 -outform DER -in ${KEY_PATH}/db.crt -out ${KEY_PATH}/db.cer
    cert-to-efi-sig-list -g `uuidgen` ${KEY_PATH}/db.crt db.esl
    sign-efi-sig-list -k KEK.key -c KEK.crt db db.esl ${KEY_PATH}/db.auth
fi

echo -e "=============================================================="
echo -e "### Create ${GRUBX64}.unsigned ####"
echo -e "=============================================================="

echo "grub-mkstandalone --directory /usr/lib/grub/x86_64-efi \n
                  --output ${GRUBX64}.unsigned \n
                  --fonts="/boot/grub/fonts/gooroom-font.pf2" \n
                  --format x86_64-efi \n
                  --pubkey ${BOOT_KEY_FILE} \n
                  --install-modules="" \n
                  --modules="boot part_gpt part_msdos fat ext2 normal configfile lspci ls reboot datetime time loadenv search help gfxmenu gfxterm gfxterm_menu gfxterm_background all_video png gettext linuxefi gcry_rsa test echo squash4 iso9660 exfat cpio_be cpio crypto gcry_sha256 gcry_sha512 tpm" \n
                    "themes/background/gooroom_grub_background_logo.png=/usr/lib/grub/x86_64-efi/themes/background/gooroom_grub_background_logo.png" \n
                    "themes/warningimages/verified_boot_fail.png=/usr/lib/grub/x86_64-efi/themes/warningimages/verified_boot_fail.png" \n
                    "themes/warningimages/verified_boot_config_error.png=/usr/lib/grub/x86_64-efi/themes/warningimages/verified_boot_config_error.png" \n
                    "boot/grub/fonts/gooroom-font.pf2=/boot/grub/fonts/gooroom-font.pf2" \n
                    "boot/grub/grub.cfg=/usr/lib/grub/x86_64-efi/grubconf/embedded.cfg""

# Create ./.grubx64.efi
grub-mkstandalone --directory /usr/lib/grub/x86_64-efi \
                  --output ${GRUBX64}.unsigned \
                  --fonts="/boot/grub/fonts/gooroom-font.pf2" \
                  --format x86_64-efi \
                  --pubkey ${BOOT_KEY_FILE} \
                  --install-modules="" \
                  --modules="boot part_gpt part_msdos fat ext2 normal configfile lspci ls reboot datetime time loadenv search help gfxmenu gfxterm gfxterm_menu gfxterm_background all_video png gettext linuxefi gcry_rsa test echo squash4 iso9660 exfat cpio_be cpio crypto gcry_sha256 gcry_sha512 tpm" \
                    "themes/background/gooroom_grub_background_logo.png=/usr/lib/grub/x86_64-efi/themes/background/gooroom_grub_background_logo.png" \
                    "themes/warningimages/verified_boot_fail.png=/usr/lib/grub/x86_64-efi/themes/warningimages/verified_boot_fail.png" \
                    "themes/warningimages/verified_boot_config_error.png=/usr/lib/grub/x86_64-efi/themes/warningimages/verified_boot_config_error.png" \
                    "boot/grub/fonts/gooroom-font.pf2=/boot/grub/fonts/gooroom-font.pf2" \
                    "boot/grub/grub.cfg=/usr/lib/grub/x86_64-efi/grubconf/embedded.cfg"

echo -e "================================================"
echo -e "### Sign ${GRUBX64} ####"
echo -e "================================================"

# When the build is completed in the rules file, copy db.crt and db.key to $KEY_PATH ($key_path in rules)
echo -e ">>> sbsign --key ${KEY_PATH}/db.key --cert ${KEY_PATH}/db.crt --output ${GRUBX64}.signed ${GRUBX64}.unsigned"
sbsign --key ${KEY_PATH}/db.key --cert ${KEY_PATH}/db.crt --output ${GRUBX64}.signed ${GRUBX64}.unsigned

cp ${GRUBX64}.signed ${GRUBX64}
echo -e "================================================"
echo -e "### Create ${GRUBCFG} ###"
echo -e "================================================"

## Update 10_linux
if [ -e /etc/gooroom/adjustments/gooroom-adjustments-grub.execute ]; then
  /etc/gooroom/adjustments/gooroom-adjustments-grub.execute
fi

## update grub.cfg
sed -i -e 's@\/usr\/share\/plymouth\/themes\/gooroom@\(memdisk\)\/themes\/background@g' ${GRUBCFG}
sed -i -e 's@font=\"\/usr\/share\/grub/unicode.pf2\"@font=\"\(memdisk\)\/boot\/grub\/fonts\/unicode.pf2\"@g' ${GRUBCFG}

