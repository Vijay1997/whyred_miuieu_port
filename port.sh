#!/usr/bin/env bash
export LOCALDIR=`cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd`
export TOOLS=${LOCALDIR}/tools
export DEVICE=lavender
export TYPE=eu
export VERSIONS=(beta)
export SDAT2IMG=${TOOLS}/sdat2img.py
export IMG2SDAT=${TOOLS}/img2sdat.py
export IMGEXTRACT=${TOOLS}/imgextractor.py
export MKUSERIMG=${TOOLS}/mkuserimg_mke2fs.sh
export APKTOOL=${TOOLS}/apktool
export SYSTEMDIR=${LOCALDIR}/system
export VENDORDIR=${LOCALDIR}/vendor
export OUTDIR=${LOCALDIR}/out
export INDIR=${LOCALDIR}/in
export fframeworkres="${SYSTEMDIR}/system/framework/framework-res.apk"
export fframeworkextres="${SYSTEMDIR}/system/framework/framework-ext-res/framework-ext-res.apk"
export fmiuisystem="${SYSTEMDIR}/system/app/miuisystem/miuisystem.apk"
export fmiui="${SYSTEMDIR}/system/app/miui/miui.apk"

date=`date +%Y%m%d%H%M%S`
for VERSION in ${VERSIONS[@]}; do
if [ "${TYPE}" = "global" ]; then
    python3 ${LOCALDIR}/${TYPE}.py ${DEVICE} ${VERSION}
    URL=$(cat ${LOCALDIR}/url)
    ZIPNAME=$(echo ${URL} | cut -d / -f 5)
elif [ "${TYPE}" = "mmx" ]; then
    python3 ${LOCALDIR}/${TYPE}.py ${DEVICE} ${VERSION}
    URL=$(cat ${LOCALDIR}/url)
    ZIPNAME=$(echo ${URL} | cut -d / -f 9)
elif [ "${TYPE}" = "eu" ]; then
    python3 ${LOCALDIR}/${TYPE}.py ${DEVICE} ${VERSION}
    URL=$(cat ${LOCALDIR}/url)
    ZIPNAME=$(echo ${URL} | cut -d / -f 10)
    URL=https://telkomuniversity.dl.sourceforge.net/project/xiaomi-eu-multilang-miui-roms/xiaomi.eu/MIUI-STABLE-RELEASES/MIUIv12/xiaomi.eu_multi_HMNote7_V12.5.3.0.QFGCNXM_v12-10.zip
else
    echo "Specify TYPE"
fi
ssh-keyscan -t ecdsa -p 22 -H frs.sourceforge.net 2>&1 | tee -a /root/.ssh/known_hosts


NEWZIP=$(sed "s/lavender/whyred/g;s/LAVENDER/WHYRED/g;s/Lavender/Whyred/g;s/HMNote7/HMNote5Pro/g;s/.zip/-$date.zip/g" <<< $ZIPNAME)
rm -rf ${LOCALDIR}/url
rm -rf ${INDIR} ${OUTDIR}
mkdir -p ${INDIR}
mkdir -p ${OUTDIR}

rm -rf ${LOCALDIR}/flashable/system.*
rm -rf ${LOCALDIR}/flashable/vendor.*

EUDATE=$(echo ${ZIPNAME} | cut -d _ -f 4)

git config --global user.email "vijaykumark1997@gmail.com"
git config --global user.name "vijay1997"

# download and Unzip
echo "Downloading ${ZIPNAME}"
aria2c -x16 -j$(nproc) -q -d "${INDIR}" -o "${ZIPNAME}" ${URL}

partitions=(system vendor)
for partition in ${partitions[@]}; do
echo "Extracting ${partition} to ${INDIR}"
7z e "${INDIR}/${ZIPNAME}" ${partition}.new.dat.br ${partition}.transfer.list -o"$INDIR"
brotli -df ${INDIR}/${partition}.new.dat.br
$SDAT2IMG ${INDIR}/${partition}.transfer.list ${INDIR}/${partition}.new.dat ${INDIR}/${partition}.img > /dev/null
rm -rf ${INDIR}/${partition}.transfer.list ${INDIR}/${partition}.new.dat*
python3 $IMGEXTRACT ${INDIR}/${partition}.img .
rm -rf ${INDIR}/${partition}.img
done

# import APKTOOL frameworks
${APKTOOL} if ${fframeworkres}
${APKTOOL} if ${fframeworkextres}
${APKTOOL} if ${fmiui}
${APKTOOL} if ${fmiuisystem}

patch_rom() {
echo "Patching system and vendor"
rm ${VENDORDIR}/etc/init/android.hardware.gatekeeper@1.0-service-qti.rc
rm ${VENDORDIR}/etc/init/android.hardware.keymaster@4.0-service-qti.rc
# app
rm -rf ${SYSTEMDIR}/system/app/Email
rm -rf ${SYSTEMDIR}/system/app/MiuiVideoGlobal
rm -rf ${SYSTEMDIR}/system/app/MiPicks
rm -rf ${SYSTEMDIR}/system/app/InMipay
rm -rf ${SYSTEMDIR}/system/app/Updater
# priv-app
rm -rf ${SYSTEMDIR}/system/priv-app/Browser
rm -rf ${SYSTEMDIR}/system/priv-app/MiBrowserGlobal
rm -rf ${SYSTEMDIR}/system/priv-app/MiuiBrowserGlobal
rm -rf ${SYSTEMDIR}/system/priv-app/MiDrop
rm -rf ${SYSTEMDIR}/system/priv-app/MiuiCamera
rm -rf ${SYSTEMDIR}/system/priv-app/Updater
# data-app
rm -rf ${SYSTEMDIR}/system/data-app/PeelMiRemote
rm -rf ${SYSTEMDIR}/system/data-app/XMRemoteController
# product/app
rm -rf ${SYSTEMDIR}/system/product/app/YouTube
rm -rf ${SYSTEMDIR}/system/product/app/Maps
rm -rf ${SYSTEMDIR}/system/product/app/Gmail2
# theme
rm -rf ${SYSTEMDIR}/system/media/theme/miui_mod_icons
# vendor/overlay
rm -rf ${VENDORDIR}/app/NotchOverlay
rm -rf ${VENDORDIR}/overlay/DevicesOverlay.apk
rm -rf ${VENDORDIR}/overlay/DevicesAndroidOverlay.apk

rsync -ra ${LOCALDIR}/whyred/audio/vendor/ ${VENDORDIR}
rsync -ra ${LOCALDIR}/whyred/camera/vendor/ ${VENDORDIR}
rsync -ra ${LOCALDIR}/whyred/display/vendor/ ${VENDORDIR}
rsync -ra ${LOCALDIR}/whyred/fingerprint/vendor/ ${VENDORDIR}
rsync -ra ${LOCALDIR}/whyred/keymaster/vendor/ ${VENDORDIR}
rsync -ra ${LOCALDIR}/whyred/sensors/vendor/ ${VENDORDIR}
rsync -ra ${LOCALDIR}/whyred/thermal/vendor/ ${VENDORDIR}
rsync -ra ${LOCALDIR}/whyred/wifi/vendor/ ${VENDORDIR}
rsync -ra ${LOCALDIR}/whyred/app/vendor/ ${VENDORDIR}

rsync -ra ${LOCALDIR}/whyred/app/system/ ${LOCALDIR}/system
rsync -ra ${LOCALDIR}/customizations/system/ ${LOCALDIR}/system

# generate overlays
${LOCALDIR}/overlay/build.sh accent
${LOCALDIR}/overlay/build.sh custom
#${LOCALDIR}/overlay/build.sh language
${LOCALDIR}/overlay/build.sh whyred

#fstab
sed -i "s/forceencrypt/encryptable/g" ${VENDORDIR}/etc/fstab.qcom
sed -i "/\/dev\/block\/bootdevice\/by-name\/system/d" ${VENDORDIR}/etc/fstab.qcom
sed -i "\/dev\/block\/bootdevice\/by-name\/userdata/a /dev/block/bootdevice/by-name/cust       /cust                  ext4   ro,nosuid,nodev,barrier=1                        wait,check" ${VENDORDIR}/etc/fstab.qcom

# manifest
sed -i "/<name>android.hardware.keymaster<\/name>/!b;n;n;c\ \ \ \ \ \ \  <version>3.0</version>" ${VENDORDIR}/etc/vintf/manifest.xml
sed -i "/<fqname>@4.0::IKeymasterDevice\/default<\/fqname>/!b;c\ \ \ \ \ \ \ \ <fqname>@3.0::IKeymasterDevice/default</fqname>" ${VENDORDIR}/etc/vintf/manifest.xml

# postboot
sed -i "s/start vendor.cdsprpcd/\# start vendor.cdsprpcd/g" ${VENDORDIR}/bin/init.qcom.post_boot.sh

# build.prop
sed -i "s/ro.product.vendor.name=lavender/ro.product.vendor.name=whyred/g" ${VENDORDIR}/build.prop
sed -i "s/ro.product.vendor.device=lavender/ro.product.vendor.device=whyred/g" ${VENDORDIR}/build.prop
sed -i "s/ro.product.vendor.model=Redmi Note 7/ro.product.vendor.model=Redmi Note 5/g" ${VENDORDIR}/build.prop
sed -i -e "/build.fingerprint_real/s/lavender/whyred/" ${VENDORDIR}/build.prop
sed -i -e "/build.fingerprint_real/s/lavender/whyred/" ${VENDORDIR}/build.prop

sed -i "s/ro.product.system.name=lavender/ro.product.system.name=whyred/g" ${SYSTEMDIR}/system/build.prop
sed -i "s/ro.product.system.device=lavender/ro.product.system.device=whyred/g" ${SYSTEMDIR}/system/build.prop
sed -i "s/ro.product.system.model=Redmi Note 7/ro.product.system.model=Redmi Note 5/g" ${SYSTEMDIR}/system/build.prop
sed -i "s/persist.vendor.camera.model=Redmi Note 7/persist.vendor.camera.model=Redmi Note 5/g" ${SYSTEMDIR}/system/build.prop
sed -i -e "/build.fingerprint_real/s/lavender/whyred/" ${SYSTEMDIR}/system/build.prop
sed -i -e "/build.fingerprint_real/s/lavender/whyred/" ${SYSTEMDIR}/system/build.prop

sed -i "s/ro.product.odm.name=lavender/ro.product.odm.name=whyred/g" ${VENDORDIR}/odm/etc/build.prop
sed -i "s/ro.product.odm.device=lavender/ro.product.odm.device=whyred/g" ${VENDORDIR}/odm/etc/build.prop
sed -i "s/ro.product.odm.model=Redmi Note 7/ro.product.odm.model=Redmi Note 5/g" ${VENDORDIR}/odm/etc/build.prop
sed -i -e "/build.fingerprint_real/s/lavender/whyred/" ${VENDORDIR}/odm/etc/build.prop
sed -i -e "/build.fingerprint_real/s/lavender/whyred/" ${VENDORDIR}/odm/etc/build.prop

sed -i "/ro.miui.notch=1/d" ${SYSTEMDIR}/system/build.prop
sed -i "s/sys.paper_mode_max_level=255/sys.paper_mode_max_level=400/g" ${SYSTEMDIR}/system/build.prop

cat ${LOCALDIR}/whyred/system.prop >> ${SYSTEMDIR}/system/build.prop
cat ${LOCALDIR}/whyred/vendor.prop >> ${VENDORDIR}/build.prop

# device_features
rm -rf ${SYSTEMDIR}/system/etc/device_features/lavender.xml
rm -rf ${VENDORDIR}/etc/device_features/lavender.xml

# Patch blobs
bash ${LOCALDIR}/whyred/patch/services_jar.sh

# file_contexts
echo "Patching file_contexts"
cat ${LOCALDIR}/overlay/system_file_contexts >> ${LOCALDIR}/config/system_file_contexts
cat ${LOCALDIR}/whyred/app/config/system_file_contexts >> ${LOCALDIR}/config/system_file_contexts
cat ${LOCALDIR}/customizations/config/system_file_contexts >> ${LOCALDIR}/config/system_file_contexts
cat ${LOCALDIR}/whyred/app/config/vendor_file_contexts >> ${LOCALDIR}/config/vendor_file_contexts
cat ${LOCALDIR}/whyred/audio/config/vendor_file_contexts >> ${LOCALDIR}/config/vendor_file_contexts
cat ${LOCALDIR}/whyred/camera/config/vendor_file_contexts >> ${LOCALDIR}/config/vendor_file_contexts
cat ${LOCALDIR}/whyred/display/config/vendor_file_contexts >> ${LOCALDIR}/config/vendor_file_contexts
cat ${LOCALDIR}/whyred/fingerprint/config/vendor_file_contexts >> ${LOCALDIR}/config/vendor_file_contexts
cat ${LOCALDIR}/whyred/keymaster/config/vendor_file_contexts >> ${LOCALDIR}/config/vendor_file_contexts
cat ${LOCALDIR}/overlay/vendor_file_contexts >> ${LOCALDIR}/config/vendor_file_contexts

# fs_config
echo "Patching fs_config"
cat ${LOCALDIR}/overlay/system_fs_config >> ${LOCALDIR}/config/system_fs_config
cat ${LOCALDIR}/whyred/app/config/system_fs_config >> ${LOCALDIR}/config/system_fs_config
cat ${LOCALDIR}/customizations/config/system_fs_config >> ${LOCALDIR}/config/system_fs_config
cat ${LOCALDIR}/whyred/app/config/vendor_fs_config >> ${LOCALDIR}/config/vendor_fs_config
cat ${LOCALDIR}/whyred/audio/config/vendor_fs_config >> ${LOCALDIR}/config/vendor_fs_config
cat ${LOCALDIR}/whyred/camera/config/vendor_fs_config >> ${LOCALDIR}/config/vendor_fs_config
cat ${LOCALDIR}/whyred/display/config/vendor_fs_config >> ${LOCALDIR}/config/vendor_fs_config
cat ${LOCALDIR}/whyred/fingerprint/config/vendor_fs_config >> ${LOCALDIR}/config/vendor_fs_config
cat ${LOCALDIR}/whyred/keymaster/config/vendor_fs_config >> ${LOCALDIR}/config/vendor_fs_config
cat ${LOCALDIR}/overlay/vendor_fs_config >> ${LOCALDIR}/config/vendor_fs_config
}

bytesToHuman() {
    b=${1:-0}; d=''; s=0; S=(Bytes {K,M,G,T,P,E,Z,Y}iB)
    while ((b > 1024)); do
        d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
        b=$((b / 1024))
        let s++
    done
    echo "$b$d ${S[$s]}"
}

# mk img
mk_img() {
ssize=3221225472
vsize=2147483648
pvsize=`du -sk ${VENDORDIR} | awk '{$1*=1024;printf $1}'`
pssize=`du -sk ${SYSTEMDIR} | awk '{$1*=1024;printf $1}'`
sout=${OUTDIR}/system.img
vout=${OUTDIR}/vendor.img
vfsconfig=${LOCALDIR}/config/vendor_fs_config
sfsconfig=${LOCALDIR}/config/system_fs_config
vfcontexts=${LOCALDIR}/config/vendor_file_contexts
sfcontexts=${LOCALDIR}/config/system_file_contexts

echo "Creating system.img"
echo "system.img size: $(bytesToHuman $pssize)"
$MKUSERIMG -s "${SYSTEMDIR}" "$sout" ext4 system $ssize -C $sfsconfig $sfcontexts -T 0  -L system > /dev/null || exit 1

echo "Creating vendor.img"
echo "vendor.img size: $(bytesToHuman $pvsize)"
$MKUSERIMG -s "${VENDORDIR}" "$vout" ext4 vendor $vsize -C $vfsconfig $vfcontexts -T 0  -L vendor > /dev/null || exit 1

rm -rf ${LOCALDIR}/config
rm -rf ${SYSTEMDIR}
rm -rf ${VENDORDIR}
}

mk_zip() {
    echo "Creating ${NEWZIP}"
    rm -rf ${NEWZIP}
    cp flashable/flashable.zip ${NEWZIP}
    $IMG2SDAT $vout -o flashable -v 4 -p vendor > /dev/null
    $IMG2SDAT $sout -o flashable -v 4 -p system > /dev/null
    cd flashable
   
   

    echo "Compressing system.new.dat"
    brotli -7 system.new.dat
    echo "Conpressing vendor.new.dat"
    brotli -7 vendor.new.dat

    rm system.new.dat || exit 1
    rm vendor.new.dat || exit 1

    zip -rv9 ../${NEWZIP}  boot.img system.new.dat.br system.patch.dat system.transfer.list vendor.new.dat.br vendor.patch.dat vendor.transfer.list
    cd ..
}

patch_rom
mk_img || continue
mk_zip

rm -rf ${INDIR} ${OUTDIR}

if [ -f ${LOCALDIR}/${NEWZIP} ]; then
   
   scp ${NEWZIP} vijaykumark1997@frs.sourceforge.net:/home/frs/project/whyredport
fi
done












