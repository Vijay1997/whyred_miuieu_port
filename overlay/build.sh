#!/usr/bin/env bash
OVERLAYDIR=${LOCALDIR}/overlay

if ! command -v aapt > /dev/null;then
    echo "Please install aapt (apt install aapt should do)"
    exit 1
fi

device=$1

rm -rf ${OVERLAYDIR}/${device}-log
paths=${OVERLAYDIR}/$device/overlay
overlays="$(ls -d ${paths}/* | xargs -n 1 basename )"
outdir=${OVERLAYDIR}/${device}/out
rm -rf ${outdir}
mkdir -p ${outdir}

for overlay in ${overlays[@]}; do
name=$device-overlay-$overlay
path=${paths}/$overlay
echo "building $name"

aapt package -v -f -F "${outdir}/${name}-unsigned.apk" -M "$path/AndroidManifest.xml" -S "$path/res" -I ${fframeworkres} -I ${frameworkextres} -I ${fmiui} -I ${fmiuisystem} &>> $LOCALDIR/${device}-log
if [ "$2" == "product" ]; then
java -jar ${TOOLS}/signapk/signapk.jar ${TOOLS}/keys/platform.x509.pem ${TOOLS}/keys/platform.pk8 "${outdir}/${name}-unsigned.apk" "${SYSTEMDIR}/system/product/overlay/${name}.apk"
if [ "$2" == "vendor" ]; then
java -jar ${TOOLS}/signapk/signapk.jar ${TOOLS}/keys/platform.x509.pem ${TOOLS}/keys/platform.pk8 "${outdir}/${name}-unsigned.apk" "${VENDORDIR}/overlay/${name}.apk"
fi
rm -rf ${outdir}
done
