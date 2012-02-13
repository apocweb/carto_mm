#!/bin/bash

domain="Validation Champlan"
ipmask=""
scan=0
rootnode="Validation"
user="webadmin"
mindfile="valid_champlan.mm"
nmap=0
inputfile=""
nmaplog="nmap$$.log"
tmp="/tmp/$$.tmp"
tmp2="/tmp/$$_2.tmp"
option="-o sfr"

## Insert un node dans le mindfile
node()
{
  if [ $# -ge 1 ]; then
    content=$1
    shift
    attr=""
    for a in $*; do
      attr="$attr $a=\"$a\""
    done
    echo "<node TEXT=\"$content\" ${attr}>" >> $mindfile
  else
    echo "</node>" >> $mindfile
  fi
}

## Sortie d'erreur pour les fonctions
exit_error()
{
  echo -n "ERREUR: fonction $1" >&2
  shift
  echo ", params $*" >&2
  exit 1
}

## Scan un range IP de classe C pour voir si le port TCP 22 est ouvert
## L'argument doit etre une IP valide ou un CIDR
my_nmap()
{
  if [ $# -ne 1 ]; then
    exit_error "my_nmap" $@
  fi

  byte_regexp='(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)'
  ip_regexp="^${byte_regexp}\.${byte_regexp}\.${byte_regexp}\.${byte_regexp}$"
  ip=$(echo $1|cut -d "/" -f1)
  if [ $(echo $ip|grep -Eo "$ip_regexp"|wc -c) -ne $(echo $ip|wc -c) ]; then
    echo "Error: invalid IP address" >&2
  fi
 
  network=$(echo $ip|sed s/\.[0-9]*$//)
  host=$(echo $ip|sed s/^[0-9]*\.[0-9]*\.[0-9]*\.//)

  rm -f $tmp
  while [ $host -le 254 ]; do
    ip="${network}.${host}"
    ssh -o ConnectTimeout=1 $user@$ip "echo \"\$HOSTNAME ($ip)\"" >> $tmp
    host=$(($host + 1))
  done
  cat $tmp | grep -v "Connection timed out" >> $nmaplog
}

## Mister proper cleaning :o)
mister_proper()
{
  rm -f $nmaplog
  rm -f $tmp
  #rm -f $nmaplog
}

usage()
{
  name=$(echo $0 | sed s#\./##)
  echo "NAME
	$name - Graph host information from network into a mind map

SYNOPSIS
	$name [dfmnrsu] -s CIDR
	$name [dfmnrsu] -f file

DESCRIPTION
$name is a program for logging into a remote machine with ssh and collecting host information into a mind map (xml tree).
It can scan ssh specified host range, try to connect and collect configuration. The scanning machine needs ssh public keys to connect the remote machines.

The options are as follows:

        -d pattern
		connect only to hosts that match the pattern

	-f file
		read hosts to from file
                the file format is: HOSTNAME (IP) 
                you can add a user for the ssh connection like this: HOSTNAME (IP) || USER

        -m mindname
		mind map filename. Default is ${mindfile}

        -n
		force using nmap

        -o sonde_opt
		call sonde.sh on remote hosts like this: sonde.sh -o sonde_opt

        -r rootnode
		the mind map rootnode name. Default is ${rootnode}

	-s CIDR
		scan with nmap or try ssh connect on TCP 22
		If using without nmap (default option), it have to be a valid IP. The scan is performed on the class C net
work of this IP.
                If using with nmap (option n), it should be a CIDR.

        -u user
		ssh connection default username: ssh user@ip
                Default is ${user}

" >&2
  exit 1
}

## Main
while getopts d:f:m:no:r:s:u: o 2> /dev/null
do
	case "$o" in
	d)	domain="$OPTARG";;
	f)	inputfile="$OPTARG";;
	m)	mindfile="$OPTARG";;
	n)	nmap=1;;
        o)	option="-o $OPTARG";;
	r)	rootnode="$OPTARG";;
	s)	ipmask="$OPTARG";scan=1;;
	u)	user="$OPTARG";;
	[?])	usage;;
	esac
done
if [ "$ipmask" = "" ] && [ $scan -eq 1 ]; then
  echo "ERREUR : CIDR obligatoire avec le mode scan" >&2
  echo $((2**8))
  exit 1
fi

if [ $scan -eq 1 ]; then
  if [ ${nmap} -eq 1 ]; then
    which nmap > /dev/null
    if [ $? -eq 0 ]; then
      nmap -p 22 $ipmask | grep "$domain" | sed 's/Nmap scan report for //' > $nmaplog
    else
      echo "ERROR: Nmap not found." >&2
      exit 1
    fi
  else
    my_nmap $ipmask
  fi
elif [ "$inputfile" != "" ]; then
  if [ -f $inputfile ]; then
    cp $inputfile $nmaplog
    if [ "$ipmask" != "" ]; then
      echo "L'option -f est effective. L'option -i est ignoree."
    fi
  else
    echo "ERREUR : $inputfile does not exist." >&2
    exit 1
  fi
else
  echo "ERREUR : option -f ou -s obligatoire" >&2
  exit 1
fi

echo "<map>" > $mindfile
node $rootnode
  if [ "$domain" != "" ]; then
    node "$domain"
  fi
  mindfile_basename=$(basename $mindfile)
  while read -u 3 line; do
    host=$(echo $line | sed "s/\ (.*\$//")
    ip=$(echo $line | sed "s/.*\ (//" | sed "s/).*//")
    echo $line | grep " || " > /dev/null
    if [ $? -eq 0 ]; then
      conuser=$(echo $line | sed "s/.* || //")
    else
      conuser=$user
    fi
    echo "Trying fishing on $conuser@$host ($ip)"
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no sonde.sh ${conuser}@${host}:/tmp/sonde.sh
    if [ $? -eq 0 ]; then
      ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${conuser}@${host} "cd /tmp && ./sonde.sh ${option} -f ${mindfile_basename}"
      if [ $? -eq 0 ]; then
        scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${conuser}@${host}:/tmp/${mindfile_basename} $tmp
        if [ $? -eq 0 ]; then
          remote_hostname=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${conuser}@${host} "which hostname > /dev/null 2>&1 && hostname 2> /dev/null")
          if [ $? -eq 0 ]; then
            node "$remote_hostname" "hostname"
          else
            node "$host" "hostname"
          fi
              cat $tmp >> $mindfile
            node
        else
          node "! $host !" "error"
            node "Download Error"; node
            echo "Impossible de telecharger le fichier mm depuis ${host} avec ${conuser}" >&2
          node
        fi
      else
        node "! $host !" "error"
          node "Execution Error"; node
          echo "Impossible d'executer le script sonde.sh dans /tmp sur ${host} avec ${conuser}" >&2
        node
      fi
    else
      node "! $host !" "error"
        node "Connexion Error"; node 
        echo "Connection impossible sur ${host} avec ${conuser}" >&2
      node
    fi
  done 3< $nmaplog
  if [ "$domain" != "" ]; then
    node
  fi
node
echo "</map>" >> $mindfile

mister_proper
