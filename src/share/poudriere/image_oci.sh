#!/bin/sh

ALTWORLDDIR=""
OCI_CONTAINER_ID=""
MINIMAL_PKGBASELIST="FreeBSD-caroot FreeBSD-certctl FreeBSD-clibs FreeBSD-kerberos-lib FreeBSD-libexecinfo FreeBSD-mtree FreeBSD-openssl-lib FreeBSD-pkg-bootstrap FreeBSD-rc FreeBSD-runtime FreeBSD-zoneinfo"

_oci_install_world_from_pkgbase()
{
	OSVERSION=$(awk -F '"' '/REVISION=/ { print $2 }' ${mnt}/usr/src/sys/conf/newvers.sh | cut -d '.' -f 1)
	mkdir -p ${ALTWORLDDIR:?}/etc/pkg/
	pkg_abi=$(get_pkg_abi)
	#cat > ${ALTWORLDDIR:?}/etc/pkg/local-base.conf <<- EOF
	#local: {
	#  url: file://${POUDRIERE_DATA}/images/${JAILNAME}-repo/FreeBSD:${OSVERSION}:${pkg_abi}/latest,
	#  enabled: true
	#}
	#EOF
	cat > ${ALTWORLDDIR:?}/etc/pkg/FreeBSD-base.conf <<- EOF
	FreeBSD-base: {
	  url: "https://pkg.FreeBSD.org/FreeBSD:${OSVERSION}:${pkg_abi}/base_latest",
	  mirror_type: "srv",
	  signature_type: "none"
	  fingerprints: "none"
	  enabled: yes
	}
	EOF
	pkg -o ABI_FILE="${mnt}/usr/lib/crt1.o" -o REPOS_DIR=${ALTWORLDDIR}/etc/pkg/ -o ASSUME_ALWAYS_YES=yes -r ${ALTWORLDDIR:?}/ update ${PKG_QUIET}
	msg "Installing base packages"
	pkg -o ABI_FILE="${mnt}/usr/lib/crt1.o" -o REPOS_DIR="${ALTWORLDDIR}/etc/pkg/" -o ASSUME_ALWAYS_YES=yes -r "${ALTWORLDDIR:?}/" install -r FreeBSD-base ${PKG_QUIET} -y $MINIMAL_PKGBASELIST
	#while read line; do
	#	pkg -o ABI_FILE="${mnt}/usr/lib/crt1.o" -o REPOS_DIR=${ALTWORLDDIR}/etc/pkg/ -o ASSUME_ALWAYS_YES=yes -r ${ALTWORLDDIR:?}/ install -r local ${PKG_QUIET} -y ${line}
	#done < ${PKGBASELIST}
	#rm -f ${WORLDDIR:?}/etc/pkg/local-base.conf
	rm -f ${WORLDDIR:?}/etc/pkg/FreeBSD-base.conf
	rm -rf ${ALTWORLDDIR:?}/var/db/pkg/repos
	msg "Base packages installed"
}

oci_check()
{
	case "${IMAGENAME}" in
	''|*[!A-Za-z0-9]*)
		err 1 "Name can only contain alphanumeric characters"
		;;
	esac

	[ -f "${mnt}/boot/kernel/kernel" ] || \
	    err 1 "The ${MEDIATYPE} media type requires a jail with a kernel"

	buildah --version > /dev/null || \
	    err 1 "Please install sysutils/podman-suite"
}

oci_prepare()
{
	OCI_CONTAINER_ID=$(buildah from scratch)
	ALTWORLDDIR=$(buildah mount $OCI_CONTAINER_ID)

	if [ -z "$ALTWORLDDIR" ]; then
		err 1 "buildah mount failed"
	fi
}

oci_build()
{
	mtree -deU -p ${ALTWORLDDIR:?}/ -f ${WORLDDIR:?}/etc/mtree/BSD.root.dist > /dev/null
	mtree -deU -p ${ALTWORLDDIR:?}/var -f ${WORLDDIR:?}/etc/mtree/BSD.var.dist > /dev/null
	mtree -deU -p ${ALTWORLDDIR:?}/usr -f ${WORLDDIR:?}/etc/mtree/BSD.usr.dist > /dev/null
	mtree -deU -p ${ALTWORLDDIR:?}/usr/include -f ${WORLDDIR:?}/etc/mtree/BSD.include.dist > /dev/null
	mtree -deU -p ${ALTWORLDDIR:?}/usr/lib -f ${WORLDDIR:?}/etc/mtree/BSD.debug.dist > /dev/null

	_oci_install_world_from_pkgbase

	cp -p ${WORLDDIR:?}/etc/master.passwd ${ALTWORLDDIR:?}/etc/
	pwd_mkdb -p -d ${ALTWORLDDIR:?}/etc ${ALTWORLDDIR:?}/etc/master.passwd
	cp -p ${WORLDDIR:?}/etc/group ${ALTWORLDDIR:?}/etc/
	cp ${WORLDDIR:?}/etc/termcap.small ${ALTWORLDDIR:?}/etc/termcap.small
	cp ${WORLDDIR:?}/etc/termcap.small ${ALTWORLDDIR:?}/usr/share/misc/termcap
	env DESTDIR=${ALTWORLDDIR:?} /usr/sbin/certctl rehash
}

oci_generate()
{
	if [ -n "$OCI_CONTAINER_ID" ]; then
		buildah unmount "$OCI_CONTAINER_ID"
		buildah commit --rm "$OCI_CONTAINER_ID" \
		    ${JAILNAME}-minimal:"$IMAGENAME"
	fi
}
