#!/bin/sh

exit_value=0
mindfile="out.mm"
option="no option"
tmp="/tmp/$$.tmp"
tmp2="/tmp/$$_2.tmp"
tmp3="/tmp/$$_3.tmp"
indent=0

## Insert un noeud indente dans le fichier mindfile
node()
{
  spaces=""
  i=0
  if [ $# -ge 1 ]; then
    while [ $i -lt $indent ]; do
      spaces="    $spaces"
      i=$(($i + 1))
    done
    indent=$(($indent + 1))
    content="$1"
    shift
    attr=""
    for a in $*; do
      attr="$attr $a=\"$a\""
    done 
    echo "${spaces}<node TEXT=\"${content}\" ${attr}>" >> $mindfile
  else
    indent=$(($indent - 1))
    while [ $i -lt $indent ]; do
      spaces="    $spaces"
      i=$(($i + 1))
    done
    echo "${spaces}</node>" >> $mindfile
  fi
}

## Insert un noeud contenant plusieurs lignes dans le mindfile
## L'input doit etre un fichier
node_multiline()
{
  LINES=""
  if [ $# -ge 1 ]; then
    while read LINE; do
      LINES="${LINES}&#xa;${LINE}"
    done < $1
    shift
    node "$LINES" $*; node
  fi
}

## Insert un commentaire erreur dans le mindfile
node_error()
{
  echo -n "<!-- ERREUR: $* -->" >> $mindfile
}

## Get Tomcat process with High Water Mark (for Linux)
#                        -> $xmx
# Tomcat Process -> $nom -> $xms
#                        -> $VmHWM
#                        -> uptime
get_tomcat_process()
{
  ps auxww|grep java|grep catalina|grep -v grep > $tmp
  if [ $(wc -l $tmp | cut -d " " -f1) -ne 0 ]; then
    node "Tomcat Process"
    while read PROCESS; do
      XMX=$(echo -n "$PROCESS" | grep -o '\-Xmx[0-9]*[kKmM]' | sed 's/\-Xmx//')
      XMS=$(echo -n "$PROCESS" | grep -o '\-Xms[0-9]*[kKmM]' | sed 's/\-Xms//')
      JVM=$(echo -n "$PROCESS" | grep -o '\-Djvm.route=[a-zA-Z0-9.]*\ '|sed 's/\-Djvm.route=//')
      PID=$(echo -n "$PROCESS" | tr -s ' ' | cut -d ' ' -f2)
      if [ `uname -s` = "Linux" ]; then
        VmHWM=$(cat /proc/${PID}/status | grep VmHWM | sed 's/VmHWM://' | sed 's/ //g')
        # Le time de demarrage (converti en seconde) par rapport au uptime
        START_TIME=$(($(cat /proc/$PID/stat | sed 's/.*) //' | cut -d ' ' -f20) / 100))
        # uptime en seconde
        UPTIME=$(cat /proc/uptime | cut -d '.' -f1)
        # Le temps d'execution du processus en seconde
        PROCESS_UPTIME=$(($UPTIME - $START_TIME))
      else
        VmHWM=-1
        PROCESS_UPTIME=-1
      fi
      if [ "$XMX" = "" ]; then
        XMX=-1
      fi
      if [ "$XMS" = "" ]; then
        XMS=-1
      fi
      if [ "$JVM" = "" ]; then
        JVM="Unknown Tomcat Process"
      fi
      node "$JVM" tomcatProcess
        node Xmx
          node "$XMX" xmx; node
        node
	node Xms
          node "$XMS" xms; node
	node
	node "High Water Mark"
          node "$VmHWM" VmHWM; node
	node
        node Uptime
          node "$PROCESS_UPTIME" tomcatUptime; node
        node
        node PID
          node "$PID" tomcatProcessPID; node
        node
      node
    done < $tmp
    node
  fi
}

## Get Tomcat instances configuration
# ...
get_sfr_tomcat_conf()
{
  ls /usr/local/tomcat-instances/init.d > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    node "Tomcat conf"
      for instance in $(ls /usr/local/tomcat-instances/init.d); do
        instance=$(echo $instance | sed "s@[^-]*-\(.*\)@\1@g")
        FILEPATH="/usr/local/tomcat-instances/$instance"
        if [ -d "$FILEPATH" -a "$instance" != "init.d" ]; then
          node "$instance" "tomcatinstance"

            ## Getting PID (useful for HWM biding)
            ls /usr/local/tomcat-instances/${instance}/run/ > /dev/null 2>&1
            if [ $? -eq 0 ]; then
              node PID
                for F in $(ls /usr/local/tomcat-instances/${instance}/run/*.pid 2>/dev/null); do
                  node "$(cat $F)" tomcatPID; node
                done
              node
            fi

            ## Getting deployed WEB APPS
            node Webapp
            TRY_PATH="/usr/local/tomcat-instances/${instance}/conf/server.xml"
            for p in $(find /usr/local/tomcat-instances/${instance}/conf/Catalina/ -name "*.xml" 2> /dev/null); do
              TRY_PATH="${TRY_PATH} $p"
	    done
            for FILEPATH in $TRY_PATH; do
              if [ -f $FILEPATH ]; then
                #Put the comment tags on its own line
  	        cat $FILEPATH |sed 's/<!--/\n<!--\n/g;s/-->/\n-->\n/' > $tmp2
                #Deletes multi-line comments
	        cat $tmp2 | awk 'BEGIN {toprint=1}
                /<!--/ {toprint=0}
	        /-->/ {restart_print=1}
	        toprint==1 {print $0}
	        restart_print==1 {restart_print=0;toprint=1}' > $tmp
                #Grep context path lines (that are not "ROOT")
                xmllint --format $tmp |grep '<Context ' | grep docBase |grep -v ROOT > $tmp2 2> /dev/null
                #cat $FILEPATH |grep '<Context ' |grep -v ROOT |grep -v '<!--' > $tmp2 2> /dev/null
                #Cleaning path
                cat $tmp2 |sed 's/.* docBase="//; s/".*//; s#${htdocs}/##; s#${htdocs}##; s#/usr/local/applications/##; s#/usr/local/applications-fut/##; s#/usr/local/web/##' > $tmp
                while read LINE; do
                  node "$LINE" deployWebApp; node
                done < $tmp
              fi
	    done
            node

            ## Getting technical configuration
            path="/usr/local/tomcat-instances/${instance}/conf/catalina.properties"
            if [ -f $path ]; then
              env="/usr/local/tomcat-instances/${instance}/bin/setenv.sh"
              if [ -f "$env" ]; then
                CATALINA_HOME=$(grep "CATALINA_HOME" $env | head -n 1 | cut -d "=" -f2)
                JAVA_HOME=$(grep "JAVA_HOME" $env | head -n 1 | cut -d "=" -f2)
                JPDA_PORT=$(grep "JPDA_PORT" $env | head -n 1 | cut -d "=" -f2)
                JMX_PORT=$(grep "JMX_PORT" $env | head -n 1 | cut -d "=" -f2)
                if [ "$CATALINA_HOME" != "" ]; then
                  node "CATALINA_HOME"
                    node "$CATALINA_HOME" "tomcatcatalina" ; node
                  node
                fi
                if [ "$JAVA_HOME" != "" ]; then
                  node "JAVA_HOME"
                    node "$JAVA_HOME" "tomcatjavahome" ; node
                  node
                fi
                if [ "$JPDA_PORT" != "" ]; then
                  node "jpda"
                    node "$JPDA_PORT" "tomcatjpdaport" ; node
                  node
                fi
                if [ "$JMX_PORT" != "" ]; then
                  node "jmx"
                    node "$JMX_PORT" "tomcatjmxport" ; node
                  node
                fi

              fi
              http=$(grep "tomcat.http.port" $path | cut -d "=" -f2)
              https=$(grep "tomcat.http.secure.port" $path | cut -d "=" -f2)
              shutdown=$(grep "tomcat.shutdown.port" $path | cut -d "=" -f2)
              if [ "$http" != "" ]; then
                node "http"
                  node "$http" "tomcathttpport" ; node
                node
              fi
              if [ "$https" != "" ]; then
                node "https"
                  node "$https" "tomcathttpsport" ; node
                node
              fi
              if [ "$shutdown" != "" ]; then
                node "shutdown"
                  node "$shutdown" "tomcatshutdownprot" ; node
                node
              fi
              grep "oracle" $path > /dev/null
              if [ $? -eq 0 ]; then
                node "Oracle"
                  grep ".*address=.*port=.*host.*" $path | sed 's/\\$//' | tr -d '\r' > $tmp
                  if [ $(cat $tmp | wc -l) -gt 0 ]; then
                    while read line; do
                      port=$(echo $line |sed "s/.*port=//" | sed "s/).*//")
                      host=$(echo $line |sed "s/.*host=//" | sed "s/).*//")
                      node "${host}:${port}" "tomcatoracle"; node
                    done < $tmp
                  fi
                  grep ".*oracle.*url=" $path | tr -d '\r' > $tmp
                  if [ $(cat $tmp | wc -l) -gt 0 ]; then
                    while read line; do
                      url=$(echo $line | sed "s/.*=//")
                      node "$url" "tomcatoracle"; node
                    done < $tmp
                  fi
                  grep ".*oracle.*user.*=" $path | tr -d '\r' > $tmp
                  if [ $(cat $tmp | wc -l) -gt 0 ]; then
                    while read line; do
                      user=$(echo $line | sed "s/.*=//")
                      node "$user" "tomcatoracleschema"; node
                    done < $tmp
                  fi
                node
              fi
            fi
          node
        fi
      done  
    node
  fi
}

get_sfr_tomcat_applications()
{
  find /usr/local/applications -maxdepth 3 -name "WEB-INF" 2> /dev/null > $tmp
  cat $tmp | grep 'WEB-INF$' | sed 's#/WEB-INF##' | sed 's#.*/##' > $tmp2
  if [ $(cat $tmp2 | wc -l) -ne 0 ]; then
    node Application
      while read line; do
        node "$line" application; node
      done < $tmp2
    node
  fi
}

#
# Cherche les install Tomcat dans /usr/local/
#
get_sfr_tomcat_install()
{
  echo "plop" > /dev/null
}

#
# Pour afficher le noeud Tomcat que si besoin
#
get_sfr_tomcat()
{
  mindfile_bck=$mindfile
  mindfile=$mindfile$$
  get_tomcat_process
  get_sfr_tomcat_conf
  if [ -f $mindfile ] && [ $(cat $mindfile | wc -l) -gt 0 ]; then
    node Tomcat
      cat $mindfile >> $mindfile_bck
    node
  fi
  rm $mindfile > /dev/null 2>&1
  mindfile=$mindfile_bck
}


## A revoir
# Memory -> $Memtotal
get_linux_memory()
{
  cat /proc/meminfo | grep MemTotal > $tmp
  if [ $(wc -l $tmp | cut -d " " -f1) -ne 0 ]; then
    node "Memory" memory
    while read l; do
      node "$l" memtotal; node
    done < $tmp
    node
  fi
}

## Affiche l'adresse de sous-reseau du CIDR passe en argument sur STDOUT
## Si ni bash, ni kzh, ni zsh de disponible : affiche le CIDR passe en argument
## Cette conversion pourrait se faire ailleur, c'est un peu de la geekerie ^^
get_network_from_cidr()
{
  # Decoupage et controle du CIDR passe en argument
  cidr=$1
  ip=$(echo $cidr|cut -d "/" -f1)
  mask=$(echo $cidr|cut -d "/" -f2)
  byte_regexp='(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)'
  ip_regexp="^${byte_regexp}\.${byte_regexp}\.${byte_regexp}\.${byte_regexp}$"
  cidr_rxp="[0-9]?[0-9]*\.[0-9]?[0-9]*\.[0-9]?[0-9]*\.[0-9]?[0-9]*/[0-9]?[0-9]"

  if [ $(echo $cidr|grep -Eo "$cidr_rxp"|wc -c) -ne $(echo $cidr|wc -c) ]; then
    echo "Error: invalid CIDR format" >&2 
  elif [ $(echo $ip|grep -Eo "$ip_regexp"|wc -c) -ne $(echo $ip|wc -c) ]; then
    echo "Error: invalid IP address" >&2
  elif [ $mask -gt 31 ]; then
    echo "Error: invalid mask. It have to be less than 32." >&2
  else
    # Le CIDR est valide, let's play with it
  
    # Creation du mask en binaire
    i=0
    while [ $i -lt $mask ]; do binary_mask="${binary_mask}1" ; i=$(($i + 1)); done
    while [ $i -le 31 ]; do binary_mask="${binary_mask}0" ; i=$(($i + 1)); done

    # Decoupage du mask par byte
    M1=$(echo $binary_mask|cut -c1-8)
    M2=$(echo $binary_mask|cut -c9-16)
    M3=$(echo $binary_mask|cut -c17-24)
    M4=$(echo $binary_mask|cut -c25-32)

    # Decoupage de l'IP par byte et conversion en binaire
    B1=$(echo "obase=2; $(echo $ip|cut -d '.' -f1)"|bc)
    B2=$(echo "obase=2; $(echo $ip|cut -d '.' -f2)"|bc)
    B3=$(echo "obase=2; $(echo $ip|cut -d '.' -f3)"|bc)
    B4=$(echo "obase=2; $(echo $ip|cut -d '.' -f4)"|bc)

    # Application du mask sur l'IP et conversation en decimal
    # Utilisation de bash pour le ET binaire

    # Fonctionne aussi avec ksh et zsh.
    which bash > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      B1=$(echo "echo \$((2#$B1 & 2#$M1))"|bash)
      B2=$(echo "echo \$((2#$B2 & 2#$M2))"|bash)
      B3=$(echo "echo \$((2#$B3 & 2#$M3))"|bash)
      B4=$(echo "echo \$((2#$B4 & 2#$M4))"|bash)

      # L'adresse reseau :-)
      echo "${B1}.${B2}.${B3}.${B4}"
    else
      which ksh > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        B1=$(echo "echo \$((2#$B1 & 2#$M1))"|ksh)
        B2=$(echo "echo \$((2#$B2 & 2#$M2))"|ksh)
        B3=$(echo "echo \$((2#$B3 & 2#$M3))"|ksh)
        B4=$(echo "echo \$((2#$B4 & 2#$M4))"|ksh)

        # L'adresse reseau :-)
        echo "${B1}.${B2}.${B3}.${B4}"
      else
        which zsh > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          B1=$(echo "echo \$((2#$B1 & 2#$M1))"|zsh)
          B2=$(echo "echo \$((2#$B2 & 2#$M2))"|zsh)
          B3=$(echo "echo \$((2#$B3 & 2#$M3))"|zsh)
          B4=$(echo "echo \$((2#$B4 & 2#$M4))"|zsh)

          # L'adresse reseau :-)
          echo "${B1}.${B2}.${B3}.${B4}"
        else
          # Pas de conversion, on affiche le CIDR :-(
          echo $cidr
        fi
      fi
    fi
  fi
}

## Les interfaces reseaux autre que LOOPBACK
#                       -> $ip
# Network -> $interface
#                       -> $subnet
get_linux_network()
{
  # A SFR le binaire ip n'est pas dans le path
  echo $option | grep "sfr" > /dev/null
  if [ $? -eq 0 ]; then
    /sbin/ip addr > $tmp
    ifconfig="/sbin/ifconfig"
  else
    ip addr > $tmp
    ifconfig="ifconfig"
  fi 

  # Recuperation des noms d'interface et de leur CIDR sauf pour le loopback
  cat $tmp | awk '
/^[0-9]+: +.*: </ && !/LOOPBACK/ {name=$2; toprint=1}
/inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\// {if (toprint==1) {print name $2; toprint=0}}
' > $tmp2

  # Creation des nodes
  node "Network"
  while read line; do 
    interface=$(echo $line|cut -d ":" -f1)
    cidr=$(echo $line|cut -d ":" -f2)
    ip=$(echo $cidr|sed s#/[0-9]*##)
    subnet=$(get_network_from_cidr $cidr)
    macaddr=$(${ifconfig} $interface|grep HWaddr|tr -s ' '|cut -d ' ' -f5)
    node "$interface" "interface"
      node IP
        node "$ip" "ip" ; node
      node
      node Subnet
        node "$subnet" subnet; node
      node
      node MAC
        node "$macaddr" macaddr; node
      node
    node
  done < $tmp2
  node
}

## Resolution des noms
#                -> /etc/hosts
# name resolving -> /etc/resolv.conf
#                -> /etc/nsswitch.conf
get_linux_network_name_resolving_and_routing()
{
  node "Name resolving" "resolving"
  # Recuperation du /etc/hosts
    if [ -f /etc/hosts ]; then
      node "/etc/hosts"
        cat /etc/hosts | tr -s " " > $tmp
        while read line; do
          if [ "$line" != "" ] && [ "$line" != " " ] && [ $(echo "$line#"|cut -c1) != "#" ]; then
	    ip=$(echo $line | tr -s ' ' | sed 's/^ //' | cut -d ' ' -f1)
	    host=$(echo $line | tr -s ' ' | sed 's/^ //' | cut -d ' ' -f2)
	    node "$ip" etcHosts
              node "$host" etcHostsResolv; node
	    node
          fi
        done < $tmp
      node
    fi

    # Recuperation du /etc/resolv.conf
    if [ -f /etc/resolv.conf ]; then
      node "/etc/resolv.conf" resolvconf
        #cat /etc/resolv.conf | tr -s " " > $tmp
        #while read line; do
        #  if [ "$line" != "" ] && [ "$line" != " " ] && [ $(echo "$line#"|cut -c1) != "#" ]; then
        #    node "$line" "resolv"; node
        #  fi
        #done < $tmp
        node_multiline /etc/resolv.conf resolv
      node
    fi

    # Recuperation des hosts de /etc/nsswitch.conf
    if [ -f /etc/nsswitch.conf ]; then
      node "/etc/nsswitch.conf" "nsswitchconf"
        grep hosts /etc/nsswitch.conf | tr -s " " > $tmp
        while read line; do
          if [ "$line" != "" ] && [ "$line" != " " ] && [ $(echo "$line#"|cut -c1) != "#" ]; then
            node "$line" "nsswitch"; node
          fi
        done < $tmp
      node
    fi

    # Recuperation du routage
    route_flag=0
    echo $option | grep "sfr" > /dev/null
    if [ $? -eq 0 ]; then
      /sbin/route > $tmp && /sbin/route -n > $tmp2
      if [ $? -eq 0 ]; then
        tail -$(( $(cat $tmp | wc -l) - 2)) $tmp > $tmp3 && cp $tmp3 $tmp
        if [ $? -eq 0 ]; then
          tail -$(( $(cat $tmp2 | wc -l) - 2)) $tmp2 > $tmp3 && cp $tmp3 $tmp2
          if [ $? -eq 0 ]; then
            route_flag=1
          fi
        fi
      fi
    else
      which route > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        route > $tmp && route -n > $tmp2
        if [ $? -eq 0 ]; then
          tail -$(( $(cat $tmp | wc -l) - 2)) $tmp > $tmp3 && cp $tmp3 $tmp
          if [ $? -eq 0 ]; then
            tail -$(( $(cat $tmp2 | wc -l) - 2)) $tmp2 > $tmp3 && cp $tmp3 $tmp2
            if [ $? -eq 0 ]; then
              route_flag=1
            fi
          fi
        fi
      fi
    fi
    if [ $route_flag -eq 1 ]; then
      node "Routing"
        node "route"
          while read line; do
            node "$line" "route"; node
          done < $tmp
        node
        node "route -n"
          while read line; do
            node "$line" "routen"; node
          done < $tmp2
        node
      node
    fi
  node
}

## Caracteristiques physiques des CPUs 
#                                -> lm ?
# CPU -> $chip -> $core -> $vcpu
#                                -> vme ?
get_linux_cpu()
{
  # Fait a partir du script de GBA qui permet de correler chip->core->cpu
cat /proc/cpuinfo | awk '
function dump() {print proc,core,chip,apicid,cpu_cores,siblings,model_name,lmflag,vmeflag}
/^processor/{if (proc!="") dump(); proc=chip=$3; core=0; apicid=lmflag=vmeflag="none";
             cpu_cores=siblings=1}
END {dump()}
/^physical id/{chip=$4}
/^core id/{core=$4}
/^apicid/{apicid=$3}
/^cpu cores/{cpu_cores=$4}
/^siblings/{siblings=$3}
/^model name/{model_name=$4; for (i=5; i <= NF; ++i) model_name = model_name "_" $i}
/^flags/{for (i=3; i <= NF; ++i) {if ($i=="lm") lmflag="yes"; if ($i=="vme") vmeflag="yes"}}
' > $tmp
  if [ $(wc -l $tmp|cut -d " " -f1) -ge 1 ]; then
    node "CPU" "cpu"
    for chip in $(cat $tmp|cut -d " " -f3|sort -u); do
      node "chip: $chip" "chip"
      for core in $(cat $tmp|cut -d " " -f2|sort -u); do
        node "core: $core" "core"
        while read cpu; do
          cpu_chip=$(echo $cpu|cut -d " " -f3)
          cpu_core=$(echo $cpu|cut -d " " -f2)
          if [ ${chip} -eq ${cpu_chip} ] && [ ${core} -eq ${cpu_core} ]; then
            cpu_name=$(echo $cpu|cut -d " " -f7)
            cpu_lm=$(echo $cpu|cut -d " " -f8)
            cpu_vme=$(echo $cpu|cut -d " " -f9)
            cpu_apicid=$(echo $cpu|cut -d " " -f4)
            node "$cpu_name" "cpuname"
              if [ "$cpu_lm" = "yes" ]; then
                node "x64" "cpu64"; node
              fi
              if [ "$cpu_vme" = "yes" ]; then
                node "Virtual Mode Extension available" "vme"; node
              fi
              node "apic id: $cpu_apicid" "apic"; node
            node
          fi
        done < $tmp
        node
      done
      node
    done
    node
  fi
}

## ajouter les ssh et les sudoers ?
# User -> $user
get_users()
{
  node "Users" "users"
    while read u; do
      user=$(echo $u | cut -d ":" -f1)
      root=$(echo $u | cut -d ":" -f3)
      if [ "$root" != "" ] && [ "$root" -eq 0 ]; then
        user="${user} (root)"
      fi
      if [ "$user" != "" ]; then
        node "$user" "user"; node
      fi
    done < /etc/passwd
  node
}

## Detail sur le noyau et la distribution Linux
#    -> Kernel -> $version -> $version_detailed
# OS
#    -> Distribution -> noeuds de detail de la distribution (lsb ou specific)
get_linux_os()
{
  node "OS"
    node "Kernel"
      which uname > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        version="$(cat /proc/version)"
        node "$(echo $version|cut -d ' ' -f1)"
          node "$version" "kernel"; node
        node
      else
        node "$(uname)" "kernel"
          node "$(uname -a)" "kernel_all"; node
        node
      fi
    node
    node "Distribution"
      which lsb_release > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        node "$(lsb_release -d 2>/dev/null)" "distrib"; node
        node "$(lsb_release -v 2>/dev/null)" "distrib"; node
        node "$(lsb_release -r 2>/dev/null)" "distrib"; node
        node "$(lsb_release -c 2>/dev/null)" "distrib"; node
      elif [ -f /etc/redhat-release ]; then
        node "$(cat /etc/redhat-release|tail -n 1)" "distrib"; node
      elif [ -f /etc/SuSE-release ]; then
        node "$(cat /etc/SuSE-release|tail -n 1)" "distrib"; node
      elif [ -f /etc/slackware-release ]; then
        node "$(cat /etc/slackware-release|tail -n 1)" "distrib"; node
      elif [ -f /etc/mandrake-release ]; then
        node "$(cat /etc/mandrake-release|tail -n 1)" "distrib"; node
      elif [ -f /etc/fedora-release ]; then
        node "$(cat /etc/fedora-release|tail -n 1)" "distrib"; node
      elif [ -f /etc/debian-version ]; then
         node "$(cat /etc/debian-release|tail -n 1)" "distrib"; node
      elif [ -f /etc/issue ]; then
        node "$(cat /etc/issue|tail -n 1)" "distrib"; node
      elif [ -f /etc/release ]; then
        node "$(cat /etc/release|tail -n 1)" "distrib"; node
      elif [ -f /etc/UnitedLinux-release ]; then
         node "$(cat /etc/UnitedLinux-release|tail -n 1)" "distrib"; node
      else
        node_error "No distribution information found"        
      fi
    node
#    node "Environement"
#      hostname=$(hostname)
#      if [ $? -eq 0 ]; then
#        node "Hostname"
#          node "$hostname" "hostname"; node
#        node
#      fi
#      which crontab > /dev/null 2>&1
#      if [ $? -eq 0 ]; then
#        crontab -l | sed 's/"//g' > $tmp 2> /dev/null
#        if [ $? -eq 0 ]; then
#          node "Crontab for user $USER"
#            node_multiline $tmp "cron"
#             while read line; do
#              node "$line" "cron"; node
#            done < $tmp
#          node
#        fi
#      fi
#    node
  node
}

## Recupere les NFS
## NFS -> $server -> "$remotefs mounted on $localsystem"
get_nfs()
{
  which df > /dev/null
  if [ $? -eq 0 ]; then
    df -Pt nfs|tr -s ' ' > $tmp
    if [ $(cat $tmp|wc -l) -gt 0 ]; then
      tail -n $(($(cat $tmp|wc -l) - 1)) $tmp > $tmp2
      if [ $(cat $tmp2|wc -l) -gt 0 ]; then
        node "NFS"
          for server in $(cat $tmp2|sed s/:.*//|uniq); do
            node "$server" "nfsserver"
              while read line; do
                if [ "$server"="$(echo $line|sed s/:.*//)" ]; then
                  remotefs=$(echo $line|cut -d ' ' -f1|cut -d ':' -f2)
                  localfs=$(echo $line|cut -d ' ' -f6)
                  node "$remotefs mounted on $localfs" "nfs"
                    which mount > /dev/null 2>&1
                    if [ $? -eq 0 ]; then
                      opt=$(mount | grep "$localfs" | sed 's/.*type nfs (//' | sed 's/)//')
                      node "$opt" "nfsopt"; node
                    fi
                    node "$remotefs" "remotefs"
                      node "$localfs" "localfs"; node
                    node
                  node
                fi
              done < $tmp2
            node
          done
        node
      fi
    fi
  fi
}

## Recupere la configuration des disks
#             -> partitions
# disk config -> df -k
#             -> swapon -s
get_linux_disk_config()
{
  node "disk config" "diskconfig"
  # proc/partitions
    if [ -f /proc/partitions ]; then
      node "partitions" "partitions"
        #node_multiline /proc/partitions
        cat /proc/partitions | tr -s " " | sed "s/^ //" > $tmp
        tail -n $(($(cat $tmp | wc -l) - 2)) $tmp > $tmp2
        while read line; do
          name=$(echo $line | cut -d " " -f4)
          major=$(echo $line | cut -d " " -f1)
          minor=$(echo $line | cut -d " " -f2)
          block=$(echo $line | cut -d " " -f3)
          device=$(cat /proc/devices | tr -s " " | sed "s/^ //" | grep "^$major " | tail -n 1 | cut -d " " -f2)
          node "$name" "partition"
            node "major"
              node "$major" "major"; node
              node "$device" "device"; node
            node
            node "minor"; node "$minor" "minor"; node; node
            node "block"; node "$block" "block"; node; node
          node
        done < $tmp2
      node
    fi

  # df -k
    which df > /dev/null
    if [ $? -eq 0 ]; then
      node "df -k" "dfk"
        df -k > $tmp
        node_multiline $tmp
      node
    fi

  # swapon -s
    # A SFR, le binaire est dans /sbin/
    echo $option | grep "sfr" > /dev/null
    if [ $? -eq 0 ]; then
      node "swapon -s" "swapon"
        /sbin/swapon -s > $tmp
        node_multiline $tmp
      node
    else
      which swapon > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        node "swapon -s" "swapon"
          swapon -s > $tmp
          node_multiline $tmp
        node
      fi
    fi

#    vgdisplay
#    lvdisplay
#    pvdisplay
#    ls -lL /proc/mapper/*
#    ls -lL /proc/${vgname}/*
  node
}

## Recupere les info de l'host local
get_host_info()
{
  system=`uname -s`
  echo "<!-- Begin $system sonde -->" > $mindfile
  if [ "$system" = "Linux" ]; then
    get_linux_os
    get_linux_cpu
    get_linux_memory
    get_linux_network
    get_linux_network_name_resolving_and_routing
    get_nfs
    get_linux_disk_config
    get_users
    #get_tomcat_process
    #get_sfr_tomcat
    node "Tomcat"
      get_tomcat_process
      echo $option | grep "sfr" > /dev/null
      if [ $? -eq 0 ]; then
        get_sfr_tomcat_conf
        get_sfr_tomcat_install
	get_sfr_tomcat_applications
      fi
    node
  elif [ "$system" = "SunOS" ]; then
    node "Sorry, the ${system} is not supported"; node
  elif [ "$system" = "AIX" ]; then
    node "Sorry, the ${system} is not supported"; node
  else
    node "Sorry, the ${system} is not supported"; node
  fi
  echo "<!-- End $system sonde -->" >> $mindfile
}

## Mister proper cleaning :o)
mister_proper()
{
  rm -f $tmp
  rm -f $tmp2
}

usage()
{
  name=$(echo $0 | sed s#^\./##)
  echo "NAME
	$name - Collect host information into an XML mind map style file

SYNOPSIS
	$name [-f file] [-o option]

DESCRIPTION
$name is a script that collects host information into a mind map (xml tree).
It collects configuration (network interfaces, CPU, memory, OS) and some monitoring information (Tomcat process)

The options are as follows:
	-f file 
		Specifying the file output. Default is out.mm

	-o option
		Client specific option (sfr)
" >&2
exit_value=2
}

## Main
while getopts f:o: o 2> /dev/null
do
	case "$o" in
	f)	mindfile="$OPTARG";;
	o)	option="$OPTARG";;
	[?])	usage;;
	esac
done
get_host_info
mister_proper
exit $exit_value
