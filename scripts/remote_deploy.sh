#!/bin/bash

declare method
declare -a servers
declare version
ssh_port=22
declare -a artifacts

###### FUNCTIONS #########

_addopts () {
  while getopts ":m:s:v:p:a:" optname
    do
      case "$optname" in
        "m")
          echo "Method ($optname) has value $OPTARG"
	  method=$OPTARG
          ;;
        "s")
          echo "Adding server $OPTARG"
          servers[$[${#servers[@]}+1]]=$OPTARG
          ;;
        "v")
          echo "Version ($optname) has value $OPTARG"
	  version=$OPTARG
          ;;
        "p")
          echo "Ssh-port ($optname) has value $OPTARG"
	  ssh_port=$OPTARG
          ;;
        "a")
          echo "Adding artifact $OPTARG"
	  artifacts[$[${#artifacts[@]}+1]]=$OPTARG
          ;;
        "?")
          echo "Unknown option $OPTARG"
          ;;
        ":")
          echo "No argument value for option $OPTARG"
          ;;
        *)
        # Should not occur
          echo "Unknown error while processing options"
          ;;
      esac
    done
  return $OPTIND
}

_upload_file() {
  local server=$1
  local file=$2
  local target=$3
  if [ -f $file ]; then
    cmd="scp -P${ssh_port} $file $server:$target"
    echo "Running: $cmd"
    eval $cmd
    if [ "$?" -ne "0" ]; then
      echo "The command scp -P${ssh_port} $file $server:$target failed! Quitting ..."
      exit 800
    fi
  else
    echo "File not found: $file"
    exit 801
  fi
}

_contains() {
  local n=$#
  local value=${!n}
  for ((i=1;i < $#;i++)) {
    if [ "${!i}" == "${value}" ]; then
      echo "y"
      return 0
    fi
  }
  echo "n"
  return 1
}

##########################

_addopts "$@"

valid_servers=( "localhost" "node1" "node2" "node3")

for server in ${servers[@]}
do
  if [ $(_contains "${valid_servers[@]}" $server) == "n" ]; then
    echo "Invalid server: $server"
    exit 802
  fi
done

if [ -z "$version" ]; then
  version="`grep artifactId.*parent ../pom.xml -A1 | grep version | sed -E 's/.*<version>(.*)<\/version>/\1/'`"
  read -p "Version? [$version] " input_version
  if [ $input_version ]; then
    version=$input_version
  fi
fi
yn=y
if [ -z "$method" ]; then
  while true; do
      read -p "Do you wish to upload the app from local machine? [$yn] " input_yn
      if [ $input_yn ]; then
        yn=$input_yn
      fi
      case $yn in
        [Yy]* ) deploy_from_local_files="true"
        break;;
        [Nn]* ) deploy_from_local_files="false"
        break;;
        * ) echo "You must answer yes or no.";;
      esac
  done
elif [ "local" == $method ]; then
  deploy_from_local_files="true"
elif [ "remote" == $method ]; then
  deploy_from_local_files="false"
else
  echo "Method (-m) must be remote or local. Was: $method"  
fi
if [ "true" == $deploy_from_local_files ]; then
  yn=y
  while true; do
    read -p "Have you remembered to run mvn clean install? [$yn] " input_yn
    if [ $input_yn ]; then
      yn=$input_yn
    fi
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) exit;;
      * ) echo "You must answer yes or no.";;
    esac
  done
fi

if [ -z "$ssh_port" ]; then
  while true; do
    read -p "Which ssh port do you want to connect to? [$ssh_port] " input_ssh_port
    if [ $input_ssh_port ]; then
      ssh_port=$input_ssh_port
    fi
  done
fi

if [[ $ssh_port -lt 1 || $ssh_port -gt 65536 ]]; then
  echo "You must enter a valid port number."
  exit 803;
fi

candidate_artifacts=( "webapp" )

if [ ${#artifacts[@]} -eq 0 ]; then
  for artifact in ${candidate_artifacts[@]}
  do
    while true; do
        yn=y
        read -p "Do you wish to deploy $artifact? [$yn] " input_yn
        if [ $input_yn ]; then
          yn=$input_yn
        fi
        case $yn in
          [Yy]* ) artifacts[$[${#artifacts[@]}+1]]=$artifact
          break;;
          [Nn]* )
          break;;
          * ) echo "You must answer yes or no.";;
        esac
    done
  done

  if [ ${#artifacts[@]} -eq 0 ]; then
    echo "You must choose at least one artifact!"
    exit 0;
  fi
fi

for artifact in ${artifacts[@]}
do
  if [ $(_contains "${candidate_artifacts[@]}" $artifact) == "n" ]; then
    echo "Invalid artifact: $artifact"
    exit 804
  fi
done

echo The following artifacts will be deployed: ${artifacts[@]}

server_suffix=".morisbak.net"
home="./"
script_dir="."
config_dir="../config"

targets=${servers[@]}
declare -a deploy_cmds

for target in ${targets[@]}
do
  server=$target
  user="bekkopen"
  config_file="$config_dir/deploy.config"
  startup_script="$script_dir/startup.sh"
  deploy_script="$script_dir/deploy.sh"
  monitor_script="$script_dir/server_monitor.sh"
  if [ "localhost" == $server ]; then
    server_host="$user@$server"
  else
    server_host="$user@$server$server_suffix"
  fi
  _upload_file $server_host $startup_script $home
  _upload_file $server_host $deploy_script $home
  _upload_file $server_host $config_file $home
  _upload_file $server_host $monitor_script $home
  for artifact in ${artifacts[@]}
  do
    if [ "true" == $deploy_from_local_files ]; then
      _upload_file $server_host "../$artifact/target/$artifact-$version.zip" $home
    fi
    cmd="ssh -tt -p$ssh_port $server_host \"cd $home ; nohup ./deploy.sh $artifact $version > /dev/null 2>&1 </dev/null\""
    echo "Running: $cmd"
    eval $cmd
    response=$?
    if [ $response -ne 0 ]; then
      echo "$cmd failed with exit code ${response}! Quitting ..."
      exit 805
    fi
  done
done
