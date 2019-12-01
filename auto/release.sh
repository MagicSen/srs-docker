#!/bin/bash

SRS_FILTER=`git branch|grep \*|awk '{print $2}'`
SRS_GIT=$HOME/git/srs
SRS_TAG=
SRS_MAJOR=

##################################################################################
##################################################################################
##################################################################################
# parse options.
for option
do
    case "$option" in
        -*=*)
            value=`echo "$option" | sed -e 's|[-_a-zA-Z0-9/]*=||'`
            option=`echo "$option" | sed -e 's|=[-_a-zA-Z0-9/.]*||'`
        ;;
           *) value="" ;;
    esac

    case "$option" in
        -h)                             help=yes                  ;;
        --help)                         help=yes                  ;;

        -v2)                            SRS_FILTER=v2             ;;
        --v2)                           SRS_FILTER=v2             ;;
        -v3)                            SRS_FILTER=v3             ;;
        --v3)                           SRS_FILTER=v3             ;;
        --git)                          SRS_GIT=$value            ;;
        --tag)                          SRS_TAG=$value            ;;

        *)
            echo "$0: error: invalid option \"$option\", @see $0 --help"
            exit 1
        ;;
    esac
done

if [[ -z $SRS_FILTER ]]; then
  echo "No branch"
  help=yes
fi

if [[ $SRS_FILTER != v2 && $SRS_FILTER != v3 ]]; then
  echo "Invalid filter $SRS_FILTER"
  help=yes
fi

if [[ ! -d $SRS_GIT ]]; then
  echo "No directory $SRS_GIT"
  help=yes
fi

if [[ -z $SRS_TAG ]]; then
  SRS_TAG=`(cd ../srs && git describe --tags --abbrev=0 --match ${SRS_FILTER}.0-* 2>&1)`
  if [[ $? -ne 0 ]]; then
    echo "Invalid tag $SRS_TAG of $SRS_FILTER in $SRS_GIT"
    exit -1
  fi
fi

SRS_MAJOR=`echo "v2.0-r6"|sed 's/^v//g'|awk -F '.' '{print $1}' 2>&1`
if [[ $? -ne 0 ]]; then
  echo "Invalid major version $SRS_MAJOR"
  exit -1
fi

if [[ $help == yes ]]; then
    cat << END

  -h, --help    Print this message

  -v2, --v2     Package the latest tag of 2.0release branch, such as v2.0-r7.
  -v3, --v3     Package the latest tag of 3.0release branch, such as v3.0-a2.
  --git         The SRS git source directory to fetch the latest tag. Default: $HOME/git/srs
  --tag         The tag to build the docker. Retrieve from branch.
END
    exit 0
fi

echo "Build docker for fitler=$SRS_FILTER of $SRS_GIT, tag is $SRS_TAG, major=$SRS_MAJOR"

OS=`python -mplatform 2>&1`
MACOS=NO && CENTOS=NO && UBUNTU=NO && CENTOS7=NO
echo $OS|grep -i "darwin" >/dev/null && MACOS=YES
echo $OS|grep -i "centos" >/dev/null && CENTOS=YES
echo $OS|grep -i "redhat" >/dev/null && CENTOS=YES
echo $OS|grep -i "ubuntu" >/dev/null && UBUNTU=YES
if [[ $CENTOS == YES ]]; then
    lsb_release -r|grep "7\." >/dev/null && CENTOS7=YES
fi
echo "OS is $OS(Darwin:$MACOS, CentOS:$CENTOS, Ubuntu:$UBUNTU) (CentOS7:$CENTOS7)"

if [[ $MACOS == YES ]]; then
  sed -i '' "s|^ARG tag=.*$|ARG tag=${SRS_TAG}|g" Dockerfile
else
  sed -i "s|^ARG tag=.*$|ARG tag=${SRS_TAG}|g" Dockerfile
fi

# For docker hub.
SRS_GITHUB=https://github.com/ossrs/srs.git
if [[ $MACOS == YES ]]; then
  sed -i '' "s|^ARG url=.*$|ARG url=${SRS_GITHUB}|g" Dockerfile
else
  sed -i "s|^ARG url=.*$|ARG url=${SRS_GITHUB}|g" Dockerfile
fi

git commit -am "Release $SRS_TAG to docker hub" && git push
echo "Commit changes of tag $SRS_TAG for docker"

git tag -d $SRS_TAG && git push origin :$SRS_TAG
echo "Cleanup tag $SRS_TAG for docker"

git tag $SRS_TAG && git push origin $SRS_TAG
echo "Create new tag $SRS_TAG for docker"

# For aliyun hub.
SRS_GITEE=https://gitee.com/winlinvip/srs.oschina.git
if [[ $MACOS == YES ]]; then
  sed -i '' "s|^ARG url=.*$|ARG url=${SRS_GITEE}|g" Dockerfile
else
  sed -i "s|^ARG url=.*$|ARG url=${SRS_GITEE}|g" Dockerfile
fi

git commit -am "Release $SRS_TAG to docker hub" && git push
echo "Commit changes of tag $SRS_TAG for aliyun"

git tag -d release-v$SRS_TAG && git push aliyun :release-v$SRS_TAG
echo "Cleanup tag $SRS_TAG for aliyun"

git tag release-v$SRS_TAG && git push aliyun release-v$SRS_TAG
echo "Create new tag $SRS_TAG for aliyun"

git tag -d release-v$SRS_MAJOR && git push aliyun :release-v$SRS_MAJOR
echo "Cleanup tag $SRS_MAJOR for aliyun"

git tag release-v$SRS_MAJOR && git push aliyun release-v$SRS_MAJOR
echo "Create new tag $SRS_MAJOR for aliyun"

if [[ $SRS_MAJOR == 2 ]]; then
  git tag -d release-vlatest && git push aliyun :release-vlatest
  echo "Cleanup tag latest for aliyun"

  git tag release-vlatest && git push aliyun release-vlatest
  echo "Create new tag latest for aliyun"
fi

