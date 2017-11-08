#!/bin/bash
build() {
	starttime=$(date +%s)
	if [ -z "$system" -a -z "$device" ] ; then
		echo "### Starting build: $project.$arch ###" >>$log
		dir="$project.$arch"
		logfile="${logsdir}/${logbase}_${dir}_${stamp}.txt"
		DISTRO=$distro PROJECT=$project ARCH=$arch $bin_make $target $mflags &>$logfile
		ret=$?
	fi
	if [ -n "$system" -a -z "$device" ] ; then
		echo "### Starting build: $project.$system.$arch ###" >>$log
		dir="$project.$system.$arch"
		logfile="${logsdir}/${logbase}_${dir}_${stamp}.txt"
		DISTRO=$distro PROJECT=$project SYSTEM=$system ARCH=$arch $bin_make $target $mflags &>$logfile
		ret=$?
	fi
	if [ -z "$system" -a -n "$device" ] ; then
		echo "### Starting build: $project.$device.$arch ###" >>$log
		dir="$project.$device.$arch"
		logfile="${logsdir}/${logbase}_${dir}_${stamp}.txt"
		DISTRO=$distro PROJECT=$project DEVICE=$device ARCH=$arch $bin_make $target $mflags &>$logfile
		ret=$?
	fi
	if [ -n "$system" -a -n "$device" ] ; then
		echo "### Starting build: $project.$device.$system.$arch ###" >>$log
		dir="$project.$system.$device.$arch"
		logfile="${logsdir}/${logbase}_${dir}_${stamp}.txt"
		DISTRO=$distro PROJECT=$project SYSTEM=$system DEVICE=$device ARCH=$arch $bin_make $target $mflags &>$logfile
		ret=$?
	fi
}
build_good() {
	finishtime=$(date +%s)
	buildtime=$((finishtime - starttime))
	timehuman $buildtime
	echo -n "The build of $project" >>$log
	if [ -n "$device" ] ; then
		echo -n ".$device" >>$log
	fi
	if [ -n "$system" ] ; then
		echo -n ".$system" >>$log
	fi
	echo ".$arch was successful and took $output" >>$log
	echo "Deleting files:" >>$log
	for f in target/*.kernel ; do
		if [ -f "$f" ] ; then
			rm -v target/*.kernel >>$log
		fi
	done
	for f in target/*.system ; do
		if [ -f "$f" ] ; then
			rm -v target/*.system >>$log
		fi
	done
	for f in target/*; do
		if [ -f "$f" ] ; then
			echo -n "Calculating MD5 of '$f': " >>$log
			$bin_md5sum $f > $f.md5
			echo "done." >>$log
			echo -n "Calculating SHA256 of '$f': " >>$log
			$bin_sha256sum $f > $f.sha256
			echo "done." >>$log
		fi
	done
	for f in target/*; do
		if [ -f "$f" ] ; then
			if [ ! -d "$webroot/$dir" ] ; then
				echo -n "Creating folder '$webroot/$dir': " >>$log
				mkdir -p $webroot/$dir
				echo "done." >>$log
			fi
			echo -n "Moving '$f' to '$webroot/$dir': " >>$log
			mv -f $f $webroot/$dir/
			echo "done." >>$log
		fi
	done
	echo -n "### Finished build of $project" >>$log
	if [ -n "$device" ] ; then
		echo -n ".$device" >>$log
	fi
	if [ -n "$system" ] ; then
		echo -n ".$system" >>$log
	fi
	echo ".$arch ###" >>$log
}
build_bad() {
	finishtime=$(date +%s)
	buildtime=$((finishtime - starttime))
	timehuman $buildtime
	echo -n "The build of $project" >>$log
	if [ -n "$device" ] ; then
		echo -n ".$device" >>$log
	fi
	if [ -n "$system" ] ; then
		echo -n ".$system" >>$log
	fi
	echo ".$arch failed. Time spent: $output" >>$log
	echo "Backing up any files in target folder, if false positive:" >>$log
	for f in target/* ; do
		if [ -f "$f" ] ; then
			if [ ! -d" $webroot/bad" ] ; then
				mkdir -p "$webroot/bad"
			fi
			mv -vf "$f" "$webroot/bad/" >>$log
		fi
	done
}
timehuman() {
	local t=$1
	local day=$((t/60/60/24))
	local hour=$((t/60/60%24))
	local minute=$((buildtime/60%60))
	local second=$((buildtime%60))
	output=""
	if [ $day -gt 0 ]; then
		[ $day = 1 ] && output="${output}$day day " || output="${output}$day days "
	fi
	if [ $hour -gt 0 ]; then
		[ $hour = 1 ] && output="${output}$hour hour " || output="${output}$hour hours "
	fi
	if [ $minute -gt 0 ]; then
		[ $minute = 1 ] && output="${output}$minute minute " || output="${output}$minute minutes "
	fi
	[ $second = 1 ] && output="${output}$second second" || output="${output}$second seconds"
}
show_params() {
	echo "$0 takes only this two parameters:"
	echo " force: force build even when repository git version did not change after local repository update"
	echo " update: update local repository before build (git pull)"
	exit 0
}
force="no"
git_update="no"
if [ "$#" -ne 0 ] ; then
	if [ "$#" -gt 2 ] || [ "$1" = "help" ] ; then
		show_params
	else
		if [ "$#" -eq 2 ] ; then
			if [ "$1" = "force" -a "$2" = "update" ] || [ "$1" = "update" -a "$2" = "force" ] ; then
				force="yes"
				git_update="yes"
			else
				show_params
			fi
		else
			if [ "$1" = "force" ] ; then
				force="yes"
			else
				if [ "$1" = "update" ] ; then
					git_update="yes"
				else
					show_params
				fi
			fi
		fi
	fi
fi
#
# BUILD CONFIGURATION
#
# Which distribution are we building? (Lakka, LibreELEC)
distro="Lakka"
# What branch are we using?
branch="Lakka-V2.1-dev"
# Where do we store the images?
webroot="/mnt/nas/WEB/lakka.vudiq.sk"
# Where is the build folder with cloned git repository?
#buildroot="/home/vudiq/lakka/repo/Lakka-LibreELEC"
buildroot="/mnt/nas/REPOS/Lakka"
# Make flaghs, e.g. how many parallel jobs should run (should be nr. of cores/threads on the build system)
mflags="-j8"
# Logging files, logs will be e-mailed
stamp=$(date +%Y-%m-%d_%H%M%S)
logsroot="/mnt/nas/LOGS"
logsdir="$logsroot/current"
log="$logsdir/nightlies_$stamp.txt"
logbase="build_log"
sendername="Lakka Build Job"
sender="vudiq@vps.vudiq.sk"
# comma and space separated recipients:
recipients="vudiq@vps.vudiq.sk"
subject="Lakka Nightlies Logs - $stamp"
# Which projects we want to build? (see folder projects/ in buildroot)
buildprojects="Generic RPi RPi2 imx6 OdroidC1 Odroid_C2 OdroidXU3 WeTek_Core WeTek_Hub WeTek_Play WeTek_Play_2 Gamegirl S8X2 S805 S905 Rockchip Allwinner"
# Architecture specifications for specific projects (i386, x86_64, arm, aarch64, ...)
archs_default="arm"
archs_Generic="x86_64 i386"
# Target specifications for specific projects (image, noobs, ...)
target_default="image"
target_RPi="noobs"
target_RPi2="noobs"
# System specifications for specific projects
systems_default=""
systems_imx6="cuboxi udoo"
systems_S8X2="S82 M8 T8 MXIII-1G MXIII-PLUS X8H-PLUS"
systems_S805="MXQ HD18Q M201C M201D MK808B-Plus"
systems_Allwinner="Bananapi Cubieboard2 Cubietruck orangepi_2 orangepi_lite orangepi_one orangepi_pc orangepi_plus orangepi_plus2e nanopi_m1_plus"
# Device specifications for specific projects
devices_default=""
devices_Rockchip="TinkerBoard ROCK64 MiQi"
default="default"
lockfile="$logsdir/lakka_build_job.lock"
email_logs="yes"
max_attach_size=10000000
email_size_limit=$((max_attach_size / 4 * 3))
compress_logs="yes"
storage_logs="$logsroot/backups"
if [ -f "$lockfile" ] ; then
	echo "Previous job still running. Aborting!" >&2
fi
touch "$lockfile"
# Check and set required binaries/tools
for tool in git sha256sum md5sum stat make 7z sendmail ; do
	result=$(which $tool)
	if [ $? -eq 0 ] ; then
		declare "bin_$tool=$result"
	elif [ "$tool" = "sendmail" ] ; then
		which /usr/sbin/sendmail &>/dev/null
		if [ $? -eq 0 ] ; then
			bin_sendmail=/usr/sbin/sendmail
		else
			email_logs="no"
		fi
	elif [ "$tool" = "7z" ]; then
		email_logs="no"
		compress_logs="no"
	else
		echo "Required '$tool' not found! Please install. Aborting!" >&2
		rm "$lockfile"
		exit 1
	fi
done
#
# END OF CONFIGURATION
#
nightstart=$(date +%s)
read -d '' build_intro << EOF
##### Starting Lakka nightly build script #####
*** Configuration ***
Building distribution: $distro
Branch: $branch
Update repository before build: $git_update
Force build in case of no change: $force
Building project(s): $buildprojects
Default architecture(s): $archs_default
Specific architectures:
...Generic: $archs_Generic
Default target: $target_default
Specific targets:
...RPi: $target_RPi
...RPi2: $target_RPi2
Default system(s): $systems_default
Specific systems:
...imx6: $systems_imx6
...S8X2: $systems_S8X2
...S805: $systems_S805
Allwinner: $systems_Allwinner
Default device(s): $devices_default
Specific devices:
...Rockchip: $devices_Rockchip
System settings:
web root: $webroot
build root: $buildroot
make flags: $mflags
compress logs: $compress_logs
email logs (have sendmail?): $email_logs
max attachment size (after base64): $max_attach_size
email size limit (size of the logs archive): $email_size_limit
email sender name: $sendername
email sender address: $sender
email recipients: $recipients
email subject: $subject
logs root: $logsroot
build logs: $logsdir
build logs base: $logbase
logs storage (if not e-mailed): $storage_logs
lock file: $lockfile
*** End of configuration ***
EOF
echo "$build_intro" >>$log
cd "$buildroot"
echo "In folder: `pwd`" >>$log
echo "Setting branch to '$branch':" >>$log
$bin_git checkout $branch &>>$log
if [ "$git_update" = "yes" ] ; then
	echo "Checking git status:" >>$log
	git_changed="no"
	git_remote=$($bin_git ls-remote -h origin $branch | awk '{print $1}')
	git_local=$($bin_git rev-parse HEAD)
	echo -e "Local: $git_local\nRemote: $git_remote" >>$log
	if [ "$git_local" = "$git_remote" ] ; then
		if [ "$force" = "no" ] ; then
			echo "At same version, no new builds are needed. Aborting." >>$log
			mv "$log" "$storage_logs/$log"
			rm "$lockfile"
			exit 0
		else
			echo "Repository did not change, but forced to build." >>$log
		fi
	else
		echo "Repository changed." >>$log
		echo "Updating repository:" >>$log
		$bin_git pull &>>$log
		ret=$?
		echo "Finished updating repository." >>$log
		echo "git pull returned: $ret" >>$log
		if [ $ret -gt 0 ] ; then
			echo "Failed during git pull - aborting!" >>$log
			echo "Failed during git pull - aborting!" >&2
			mv "$log" "$storage_logs/$log"
			rm "$lockfile"
			exit 1
		fi
	fi
else
	echo "Not updating repository." >>$log
fi
echo "Deleting files in 'target' folder:" >>$log
rm -vrf target/* &>>$log
for p in $buildprojects ; do
	project=$p
	# collect project specific information
	for v in archs target systems devices ; do
		vars="$v"_"$project"
		vars=$(echo ${!vars})
		vard="$v"_"$default"
		vard=$(echo ${!vard})
		varname="p_$v"
		if [ -z "$vars" ] ; then
			declare "$varname=`echo $vard`"
		else
			declare "$varname=`echo $vars`"
		fi
	done
	echo "Variables of project \"$project\": p_archs=\"$p_archs\" p_target=\"$p_target\" p_systems=\"$p_systems\" p_devices=\"$p_devices\"" >>$log
	target=$p_target
	for a in $p_archs ; do
		arch=$a
		# project has system specific builds
		if [ -n "$p_systems" -a -z "$p_devices" ] ; then
			for s in $p_systems ; do
				system=$s
				device=""
				build
				if [ $ret -eq 0 ] ; then
					build_good
				else
					build_bad
				fi
			done
		fi
		# project has device specific builtds
		if [ -z "$p_systems" -a -n "$p_devices" ] ; then
			for d in $p_devices ; do
				system=""
				device=$d
				build
				if [ $ret -eq 0 ] ; then
					build_good
				else
					build_bad
				fi

			done
		fi
		# project has device AND system specific builds
		# TODO:
		# probably not expectable, but for future such builds must
		# be treated in other way, as below, e.g. specify system + device,
		# as maybe the builds will not be for every system AND every device
		# combination
		if [ -n "$p_systems" -a -n "$p_devices" ] ; then
			for s in $p_systems ; do
				for d in $p_devices ; do
					system=$s
					device=$d
					build
					if [ $ret -eq 0 ] ; then
						build_good
					else
						build_bad
					fi
				done
			done
		fi
		# project has no specific system/device builds
		if [ -z "$p_systems" -a -z "$p_devices" ] ; then
			system=""
			device=""
			build
			if [ $ret -eq 0 ] ; then
				build_good
			else
				build_bad
			fi
		fi
	done
done
nightfinish=$(date +%s)
nightrun=$((nightfinish - nightstart))
timehuman $nightrun
echo "The nightly build took $output" >>$log
echo "##### Finished nightly builds #####" >>$log
# create archive with logs
body=$(n=$(grep " was successful and took " $log | wc -l) ; echo "Success ($n):" ; grep " was successful and took " $log ; n=$(grep " failed. Time spent: " $log | wc -l) ; echo "Failure ($n):" ; grep " failed. Time spent: " $log)
logarchive="lakka_logs_$stamp.7z"
cd "$logsdir"
if [ "$compress_logs" = "yes" ] ; then
	$bin_7z a $logarchive $logbase* $log >/dev/null
	if [ $? -eq 0 ] ; then
		have_archive="yes"
		rm -f $logbase* $log
	else
		echo "Error creating archive!" >&2
		rm -f $logarchive
		have_archive="no"
	fi
fi
if [ "$compress_logs" = "no" ] || [ "$have_archive" = "no" ] ; then
	mkdir -p "$storage_logs/$stamp"
	mv $logbase* "$storage_logs/$stamp"
	mv $log "$storage_logs/$stamp"
	logs_location="$storage_logs/$stamp"
fi
if [ "$have_archive" = "yes" ] ; then
	size=$($bin_stat --printf="%s" $logarchive)
	if [ $size -gt $email_size_limit ] ; then
		attach_archive="no"
		mv $logarchive "$storage_logs"
		logs_location="$storage_logs/$logarchive"
	else
		attach_archive="yes"
	fi
fi
#send e-mail notification
if [ "$email_logs" = "no" ] ; then
	echo "Job finished, but not sending e-mail notification (no sendmail found)." >&2
	echo "Logs can be found here: $logs_location" >&2
	echo "Summary:" >&2
	echo "$body" >&2
	rm "$lockfile"
	exit 0
fi
read -d '' emailheader << EOF
From: $sendername <$sender>
To: $recipients
Subject: $subject
Mime-Version: 1.0
EOF
if [ "$attach_archive" = "yes" ] ; then
	mimetype=$(file --mime-type $logarchive | sed 's/.*: //')
	archbase64=$(base64 $logarchive)
	rm -f $logarchive
	boundary="==Multipart_Boundardy_X_{`date +%s | md5sum | sed 's/  -//'`}x"
	read -d '' email << EOF
$emailheader
Content-Type: multipart/mixed; boundary="$boundary"

--${boundary}
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: 8bit
Content-Disposition: inline

Summary:
$body

Logs attached.

--${boundary}
Content-Type: $mimetype
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="$logarchive"

$archbase64

--${boundary}--
EOF
else
	read -d '' email << EOF
$emailheader

Summary:
$body

Logs can be found here:
$logs_location
EOF
fi
echo "$email" | $bin_sendmail -t -oi
rm "$lockfile"
