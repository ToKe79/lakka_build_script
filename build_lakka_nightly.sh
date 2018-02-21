#!/bin/bash
set -x
[ -z "$FORCE" ] && FORCE="no"
#
# BUILD CONFIGURATION
#
# Which distribution are we building? (Lakka, LibreELEC)
distro="Lakka"
# What branch are we using?
branch="Lakka-V2.1-dev"
# Where do we store the images?
webdir="/mnt/data/WEB/nightly.builds.lakka.tv"
# Where is the build folder with cloned git repository?
buildroot="/mnt/data/PROJECTS/Lakka-LibreELEC"
# Make flaghs, e.g. how many parallel jobs should run (should be nr. of cores/threads on the build system)
mflags="-j"
# Which projects we want to build? (see folder projects/ in buildroot)
buildprojects="Generic RPi RPi2 Allwinner Rockchip imx6 OdroidC1 Odroid_C2 OdroidXU3 WeTek_Core WeTek_Hub WeTek_Play WeTek_Play_2 Gamegirl S8X2 S805 S905 S912 Slice Slice3"
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
# Logging
stamp=$(date +%Y-%m-%d)
webroot="$webdir/$stamp"
logsdir="$webroot/_logs"
logname="nightly_$stamp.txt"
log="$logsdir/$logname"
logbase=""
nightstart=$(date +%s)
declare -i bad_builds=0
declare -i good_builds=0
lockfile="$HOME/lakka_build_job.lock"
#
# END OF CONFIGURATION
#
build() {
	starttime=$(date +%s)
	if [ -z "$system" -a -z "$device" ] ; then
		echo "### Starting build: $project.$arch ###" >>$log
		dir="$project.$arch"
		logfile="${logsdir}/${logbase}${dir}-${stamp}.txt"
		DISTRO=$distro PROJECT=$project ARCH=$arch $bin_make $target $mflags &>$logfile
		ret=$?
	fi
	if [ -n "$system" -a -z "$device" ] ; then
		echo "### Starting build: $project.$system.$arch ###" >>$log
		dir="$project.$system.$arch"
		logfile="${logsdir}/${logbase}${dir}_${stamp}.txt"
		DISTRO=$distro PROJECT=$project SYSTEM=$system ARCH=$arch $bin_make $target $mflags &>$logfile
		ret=$?
	fi
	if [ -z "$system" -a -n "$device" ] ; then
		echo "### Starting build: $project.$device.$arch ###" >>$log
		dir="$project.$device.$arch"
		logfile="${logsdir}/${logbase}${dir}_${stamp}.txt"
		DISTRO=$distro PROJECT=$project DEVICE=$device ARCH=$arch $bin_make $target $mflags &>$logfile
		ret=$?
	fi
	if [ -n "$system" -a -n "$device" ] ; then
		echo "### Starting build: $project.$device.$system.$arch ###" >>$log
		dir="$project.$system.$device.$arch"
		logfile="${logsdir}/${logbase}${dir}_${stamp}.txt"
		DISTRO=$distro PROJECT=$project SYSTEM=$system DEVICE=$device ARCH=$arch $bin_make $target $mflags &>$logfile
		ret=$?
	fi
}
build_good() {
	good_builds+=1
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
	for f in target/*.kernel ; do
		if [ -f "$f" ] ; then
			rm "$f"
		fi
	done
	for f in target/*.system ; do
		if [ -f "$f" ] ; then
			rm "$f"
		fi
	done
	for f in target/*; do
		if [ -f "$f" ] ; then
			$bin_md5sum "$f" > "$f.md5"
			$bin_sha256sum "$f" > "$f.sha256"
		fi
	done
	for f in target/*; do
		if [ -f "$f" ] ; then
			if [ ! -d "$webroot/$dir" ] ; then
				mkdir -p "$webroot/$dir"
			fi
			mv -f "$f" "$webroot/$dir/"
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
	bad_builds+=1
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
	for f in target/* ; do
		if [ -f "$f" ] ; then
			rm "$f"
		fi
	done
}
timehuman() {
	local t=$1
	local day=$((t/60/60/24))
	local hour=$((t/60/60%24))
	local minute=$((t/60%60))
	local second=$((t%60))
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
	if [ $second -gt 0 ] ; then
		[ $second = 1 ] && output="${output}$second second" || output="${output}$second seconds"
	fi
}
if [ -f "$lockfile" ] ; then
	echo "Previous job still running. Aborting!" >&2
	exit 1
fi
touch "$lockfile"
if [ $? -gt 0 ] ; then
	echo "Could not create lock file '$lockfile' - aborting!" >&2
	exit 1
fi
if [ -e "$webroot" ] ; then
	echo "Folder '$webroot' already exists - aborting!" >&2
	rm "$lockfile"
	exit 1
fi
mkdir -p "$logsdir"
if [ $? -gt 0 ] ; then
	echo "Could not create folder '$logsdir' - aborting!" >&2
	rm "$lockfile"
	exit 1
fi
# Check and set required binaries/tools
for tool in git sha256sum md5sum make ; do
	result=$(which $tool)
	if [ $? -eq 0 ] ; then
		declare "bin_$tool=$result"
	else
		echo "Required '$tool' not found! Please install. Aborting!" >&2
		rm "$lockfile"
		exit 1
	fi
done
read -d '' build_intro << EOF
##### Starting Lakka nightly build script #####
*** Configuration ***
Building distribution: $distro
Branch: $upstream_branch
Building project(s): $buildprojects
Default architecture(s): $archs_default
Specific architectures:
	Generic: $archs_Generic
Default target: $target_default
Specific targets:
	RPi: $target_RPi
	RPi2: $target_RPi2
Default system(s): $systems_default
Specific systems:
	imx6: $systems_imx6
	S8X2: $systems_S8X2
	S805: $systems_S805
	Allwinner: $systems_Allwinner
Default device(s): $devices_default
Specific devices:
	Rockchip: $devices_Rockchip
System settings:
web root: $webroot
build root: $buildroot
make flags: $mflags
build logs: $logsdir
lock file: $lockfile
*** End of configuration ***
EOF
echo "$build_intro" >>$log
cd "$buildroot"
echo "In folder: `pwd`" >>$log
echo "Setting branch to 'branch':" >>$log
$bin_git checkout $branch &>>$log
echo "Updating repository (git pull):" >>$log
git_message=$($bin_git pull 2>&1)
if [ $? -gt 0 ] ; then
	echo -e "Error while pull! Exiting!\nGit message:\n$git_message" >&2
	rm "$lockfile"
	rm -r $webroot
	exit 1
elif [ "$git_message" = "Already up-to-date." -a "$FORCE" = "no" ] ; then
	# no changes - aborting (no new build is necessary)
	rm "$lockfile"
	rm -r $webroot
	exit 0
else
	echo "$git_message" >>$log
	echo "Finished updating repository" >>$log
fi
# use custom unpack script with modified git handling
if [ -f "$HOME/src/unpack" ] ; then
	echo "Applying unpack script:" >>$log
	cp -vf $HOME/src/unpack $buildroot/scripts/unpack >>$log
fi
# clean target/ dir before build
for f in target/* ; do
	if [ -f "$f" ] ; then
		rm "$f"
	fi
done
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
# remove all uncommited changes
cd $buildroot
$bin_git checkout -- .
nightfinish=$(date +%s)
nightrun=$((nightfinish - nightstart))
timehuman $nightrun
echo "The nightly build took $output ($good_builds success builds / $bad_builds failed builds)" >>$log
echo "##### Finished nightly builds #####" >>$log
if [ $bad_builds -gt 0 ] ; then
	message=$(n=$(grep " failed. Time spent: " $log | wc -l) ; echo "Failure ($n):" ; grep " failed. Time spent: " $log)
	echo "$message" >&2
fi
rm "$lockfile"
