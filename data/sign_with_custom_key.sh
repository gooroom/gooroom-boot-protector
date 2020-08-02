#!/bin/bash

#
# 2017.10.11 Jongkyung Woo <jongkyung.woo@gmail.com>
#

if [ $# -eq 0 ]; then
    # /var/tmp/gooroom/keys
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

GRUBX64=/boot/efi/EFI/gooroom/grubx64.efi
VMLINUZ=/boot/vmlinuz-4.9.0-12-amd64
INITRD=/boot/initrd.img-4.9.0-12-amd64
INITRD_RECOVERY=/boot/initrd.img-4.9.0-12-amd64-recovery
GRUBCFG=/boot/grub/grub.cfg

GPG_KEY_FILE=$KEY_PATH/gooroom-2.0-secret-key.gpg
#BOOT_KEY_FILE=/etc/apt/trusted.gpg.d/gooroom-keyring-2.0.gpg
BOOT_KEY_FILE=$KEY_PATH/boot.key

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
    echo -e ">>> create PK.auth"
    openssl req -new -x509 -newkey rsa:2048 -subj "/CN=my PK/" \
	        -keyout PK.key -out PK.crt -days 3650 -nodes -sha256
    openssl x509 -outform DER -in PK.crt -out PK.cer
    cert-to-efi-sig-list -g `uuidgen` PK.crt PK.esl
    sign-efi-sig-list -k PK.key -c PK.crt PK PK.esl ${KEY_PATH}/PK.auth

    # Create KEK.auth
    echo -e ">>> create KEK.auth"
    openssl req -new -x509 -newkey rsa:2048 -subj "/CN=my KEK/" \
	        -keyout KEK.key -out KEK.crt -days 3650 -nodes -sha256
    openssl x509 -outform DER -in KEK.crt -out KEK.cer
    cert-to-efi-sig-list -g `uuidgen` KEK.crt KEK.esl
    sign-efi-sig-list -k PK.key -c PK.crt KEK KEK.esl ${KEY_PATH}/KEK.auth

    # Create db.auth
    echo -e ">>> create db.auth"
    openssl req -new -x509 -newkey rsa:2048 -subj "/CN=my db/" \
	        -keyout db.key -out db.crt -days 3650 -nodes -sha256
    openssl x509 -outform DER -in db.crt -out db.cer
    cert-to-efi-sig-list -g `uuidgen` db.crt db.esl
    sign-efi-sig-list -k KEK.key -c KEK.crt db db.esl ${KEY_PATH}/db.auth

    # Copy PK.auth KEY.auth db.auth to /boot/efi/EFI
    if [ -e /boot/efi/EFI ]; then
        cp PK.auth KEK.auth db.auth /boot/efi/EFI/
        echo -e ">>> cp PK.auth KEK.auth db.auth /boot/efi/EFI/"
    else
        echo -e ">>> /boot/efi/EFI is not exist."
        exit
    fi

else
    echo -e "=============================================================="
    echo -e "### The ${KEY_PATH}/db.key and ${KEY_PATH}/db.crt is exists"
    echo -e "# Pass the PK.auth KEK.auth db.auth creation procedure"
    echo -e "=============================================================="

    # Copy PK.auth KEY.auth db.auth to /boot/efi/EFI
    if [ -e /boot/efi/EFI ]; then
        cp PK.auth KEK.auth db.auth /boot/efi/EFI/
        echo -e ">>> cp PK.auth KEK.auth db.auth /boot/efi/EFI/"
    else
        echo -e ">>> /boot/efi/EFI is not exist."
        exit
    fi
fi

echo -e "================================================"
echo -e "### Generating the New private key with ${BOOT_KEY_FILE} ####"
echo -e "================================================"

gpg --full-generate-key
gpg --export > ${BOOT_KEY_FILE}

echo -e "=============================================================="
echo -e "### Create ${GRUBX64}.unsigned ####"
echo -e "=============================================================="

echo "grub-mkstandalone --directory /usr/lib/grub/x86_64-efi \n
                  --output ${GRUBX64}.unsigned \n
                  --fonts="/boot/grub/fonts/gooroom-font.pf2" \n
                  --format x86_64-efi \n
                  --pubkey ${BOOT_KEY_FILE} \n
                  --install-modules="" \n
                  --modules="boot part_gpt part_msdos fat ext2 normal configfile lspci ls reboot datetime time loadenv search lvm help gfxmenu gfxterm gfxterm_menu gfxterm_background all_video png gettext linuxefi tpm verify gcry_rsa test echo zfs xfs ufs2 ufs1_be ufs1 udf squash4 sfs romfs reiserfs odc ntfs nilfs2 newc minix_be minix3_be minix3 minix2_be minix2 minix jfs iso9660 hfsplus hfs exfat cpio_be cpio cbfs bfs afs affs crypto gcry_sha256 gcry_sha512" \n
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
                  --modules="boot part_gpt part_msdos fat ext2 normal configfile lspci ls reboot datetime time loadenv search lvm help gfxmenu gfxterm gfxterm_menu gfxterm_background all_video png gettext linuxefi tpm verify gcry_rsa test echo zfs xfs ufs2 ufs1_be ufs1 udf squash4 sfs romfs reiserfs odc ntfs nilfs2 newc minix_be minix3_be minix3 minix2_be minix2 minix jfs iso9660 hfsplus hfs exfat cpio_be cpio cbfs bfs afs affs crypto gcry_sha256 gcry_sha512" \
                    "themes/background/gooroom_grub_background_logo.png=/usr/lib/grub/x86_64-efi/themes/background/gooroom_grub_background_logo.png" \
                    "themes/warningimages/verified_boot_fail.png=/usr/lib/grub/x86_64-efi/themes/warningimages/verified_boot_fail.png" \
                    "themes/warningimages/verified_boot_config_error.png=/usr/lib/grub/x86_64-efi/themes/warningimages/verified_boot_config_error.png" \
                    "boot/grub/fonts/gooroom-font.pf2=/boot/grub/fonts/gooroom-font.pf2" \
                    "boot/grub/grub.cfg=/usr/lib/grub/x86_64-efi/grubconf/embedded.cfg"

echo -e "================================================"
echo -e "### Sign ${GRUBX64} ####"
echo -e "================================================"

echo -e ">>> sbsign --key ${KEY_PATH}/db.key --cert ${KEY_PATH}/db.crt --output ${GRUBX64}.signed ${GRUBX64}.unsigned"
sbsign --key ${KEY_PATH}/db.key --cert ${KEY_PATH}/db.crt --output ${GRUBX64}.signed ${GRUBX64}.unsigned

cp ${GRUBX64}.signed ${GRUBX64}

echo -e "================================================"
echo -e "### Sign ${VMLINUZ} ####"
echo -e "================================================"
gpg -v --digest-algo sha256 --detach-sign ${VMLINUZ}

echo -e "================================================"
echo -e "### Sign ${INITRD} ####"
echo -e "================================================"
gpg -v --digest-algo sha256 --detach-sign ${INITRD}

echo -e "================================================"
echo -e "### Sign ${INITRD_RECOVERY} ####"
echo -e "================================================"
gpg -v --digest-algo sha256 --detach-sign ${INITRD_RECOVERY}

echo -e "================================================"
echo -e "### Create ${GRUBCFG} ###"
echo -e "================================================"

## Update 10_linux
if [ -e /etc/gooroom/adjustments/gooroom-adjustments-grub.execute ]; then
  /etc/gooroom/adjustments/gooroom-adjustments-grub.execute
fi

grub-mkconfig -o ${GRUBCFG}
cp ${GRUBCFG} ${GRUBCFG}.legacy

sed -i -e 's@\/usr\/share\/plymouth\/themes\/gooroom@\(memdisk\)\/themes\/background@g' ${GRUBCFG}
sed -i -e 's@font=\"\/usr\/share\/grub/unicode.pf2\"@font=\"\(memdisk\)\/boot\/grub\/fonts\/unicode.pf2\"@g' ${GRUBCFG}

echo -e "================================================"
echo -e "### Sign ${GRUBCFG} ####"
echo -e "================================================"
gpg -v --digest-algo sha256 --detach-sign ${GRUBCFG}

