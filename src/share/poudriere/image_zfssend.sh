#!/bin/sh

#
# Copyright (c) 2015 Baptiste Daroussin <bapt@FreeBSD.org>
# All rights reserved.
# Copyright (c) 2021 Emmanuel Vadot <manu@FreeBSD.org>
# Copyright (c) 2018-2021 Allan Jude <allanjude@FreeBSD.org>
# Copyright (c) 2019 Marie Helene Kvello-Aune <freebsd@mhka.no>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

zfssend_check()
{
	[ -n "${IMAGESIZE}" ] || err 1 "Please specify the imagesize"

	[ -f "${mnt}/boot/kernel/kernel" ] || \
	    err 1 "The ${MEDIATYPE} media type requires a jail with a kernel"
}

zfssend_prepare()
{
	truncate -s ${IMAGESIZE} ${WRKDIR}/raw.img
	md=$(/sbin/mdconfig ${WRKDIR}/raw.img)
	zroot=${IMAGENAME}root
	msg "Creating temporary ZFS pool"
	zpool create \
	    -O mountpoint=/ \
	    -O canmount=noauto \
	    -O compression=on \
	    -O atime=off \
	    -R ${WRKDIR}/world ${zroot} /dev/${md} || exit

	msg "Creating ZFS Datasets"
	zfs create -o mountpoint=none ${zroot}/${ZFS_BEROOT_NAME}
	zfs create -o mountpoint=/ ${zroot}/${ZFS_BEROOT_NAME}/${ZFS_BOOTFS_NAME}
	zfs create -o mountpoint=/tmp -o exec=on -o setuid=off ${zroot}/tmp
	zfs create -o mountpoint=/usr -o canmount=off ${zroot}/usr
	zfs create ${zroot}/usr/home
	zfs create -o setuid=off ${zroot}/usr/ports
	zfs create ${zroot}/usr/src
	zfs create ${zroot}/usr/obj
	zfs create -o mountpoint=/var -o canmount=off ${zroot}/var
	zfs create -o exec=off -o setuid=off ${zroot}/var/audit
	zfs create -o exec=off -o setuid=off ${zroot}/var/crash
	zfs create -o exec=off -o setuid=off ${zroot}/var/log
	zfs create -o atime=on ${zroot}/var/mail
	zfs create -o setuid=off ${zroot}/var/tmp
	chmod 1777 ${WRKDIR}/world/tmp ${WRKDIR}/world/var/tmp
	ln -s /usr/home ${WRKDIR}/world/home
}

zfssend_build()
{
	zpool set bootfs=${zroot}/${ZFS_BEROOT_NAME}/${ZFS_BOOTFS_NAME} ${zroot}
	zpool set autoexpand=on ${zroot}
	zfs set canmount=noauto ${zroot}/${ZFS_BEROOT_NAME}/${ZFS_BOOTFS_NAME}
	SNAPSPEC="${zroot}@${IMAGENAME}"

	msg "Creating snapshot(s) for replication"
	zfs snapshot -r $SNAPSPEC

	# Call function to export replication stream here.
	# Test if we should create +full or +be.
	# XXX: but in a way which lets us perform both.
	# XXX: Take iso+mfs' approach
	case "${MEDIATYPE}" in
	zfssend|*+full*)
		FINALIMAGE=${IMAGENAME}.full.zfs
		zfssend_writereplicationstream "${SNAPSPEC}" "${FINALIMAGE}"
		;;
	*+be*)
		FINALIMAGE=${IMAGENAME}.be.zfs
		SNAPSPEC="${zroot}/${ZFS_BEROOT_NAME}/${ZFS_BOOTFS_NAME}@${IMAGENAME}"
		zfssend_writereplicationstream "${SNAPSPEC}" "${FINALIMAGE}"
		;;
	esac

	zpool export ${zroot}
	zroot=
	/sbin/mdconfig -d -u ${md#md}
	md=
}

zfssend_generate()
{
}

zfssend_writereplicationstream() {
	[ $# -eq 2 ] || eargs zfssend_writereplicationstream snapshot_from image_to
	msg "Creating replication stream"
	zfs send ${ZFS_SEND_FLAGS} "$1" > "${OUTPUTDIR}/$2" ||
	    err 1 "Failed to save ZFS replication stream"
}
