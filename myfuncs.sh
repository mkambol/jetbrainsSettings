
function ignoreWeka() {
    touch plugins/knowledge-flow/.kettle-ignore
    touch plugins/weka-forecasting/.kettle-ignore
    touch plugins/weka-scoring/.kettle-ignore
    }


sdbg() {
    ignoreWeka
    export OPT="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5009"

    if [ -n "$1" ]; then
        sed -i -e "s/param name=\"Threshold\" value=.*/param name=\"Threshold\" value=\"$1\" \/\>/g" classes/log4j.xml
        sed -i -e "s/priority value=[^-]+/priority value=\"$1\" \/\>/g" classes/log4j.xml
    fi
    rm -rf system/karaf/caches
    ./spoon.sh
}

sdbgs() {
    export OPT="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=y,address=5005"
    ./spoon.sh
}

run() {
    number=$1
    shift
    for i in `seq $number`; do
      $@
    done
}

pd() {
     export CATALINA_PID=/tmp/catalina.pid
     ./tomcat/bin/catalina.sh stop -force
     sleep 2

     if [ -n "$1" ]; then
         sed -i -e "s/param name=\"Threshold\" value=.*/param name=\"Threshold\" value=\"$1\" \/\>/g" tomcat/webapps/pentaho/WEB-INF/classes/log4j.xml
         sed -i -e "s/priority value=[^-]*/priority value=\"$1\" \/\>/g"                              tomcat/webapps/pentaho/WEB-INF/classes/log4j.xml
     fi

     rm -rf pentaho-solutions/system/karaf/caches
     ./start-pentaho-debug.sh
     tail -f tomcat/logs/catalina.out 
}


capture() {
    sudo dtrace -p "$1" -qn '
        syscall::write*:entry
        /pid == $target && arg0 == 1/ {
            printf("%s", copyinstr(arg1, arg2));
        }
    '
}

simba() {
    [ -d plugins ] && { cp  ~/dev/drivers/Simba/* plugins/pentaho-big-data-plugin/hadoop-configurations/$1/lib/ }
   [ -d pentaho-solutions ] && { cp ~/dev/drivers/Simba/* pentaho-solutions/system/kettle/plugins/pentaho-big-data-plugin/hadoop-configurations/$1/lib/ }
   
}

dikerb() {
   [ -d pentaho-solutions ] && { pushd pentaho-solutions/system/kettle }
   pwd
   sed -i -e "s/hadoop.configuration=.*/hadoop.configuration=$1/g" plugins/pentaho-big-data-plugin/plugin.properties
   sed -i -e "s/superuser.provider=.*/superuser.provider=kerb/g" plugins/pentaho-big-data-plugin/hadoop-configurations/$1/config.properties
   sed -i -e "s/kerberos.id=.*/kerberos.id=kerb/g" plugins/pentaho-big-data-plugin/hadoop-configurations/$1/config.properties
   sed -i -e "s/kerberos.principal=.*/kerberos.principal=devuser@PENTAHOQA.COM/g" plugins/pentaho-big-data-plugin/hadoop-configurations/$1/config.properties
   sed -i -e "s/kerberos.password=.*/kerberos.password=password/g" plugins/pentaho-big-data-plugin/hadoop-configurations/$1/config.properties
#   cat plugins/pentaho-big-data-plugin/hadoop-configurations/$1/config.properties
   [ -d ../kettle ] && { popd }
}

di_noauth() {
   [ -d pentaho-solutions ] && { pushd pentaho-solutions/system/kettle }
   pwd
   sed -i -e "s/hadoop.configuration=.*/hadoop.configuration=$1/g" plugins/pentaho-big-data-plugin/plugin.properties
   sed -i -e "s/superuser.provider=.*/superuser.provider=NO_AUTH/g" plugins/pentaho-big-data-plugin/hadoop-configurations/$1/config.properties
#   cat plugins/pentaho-big-data-plugin/hadoop-configurations/$1/config.properties
   [ -d ../kettle ] && { popd }
}

di_imp_config() {
# copy impersonating config.properties to shim
   set -x
   sed -i -e "s/hadoop.configuration=.*/hadoop.configuration=$1/g" plugins/pentaho-big-data-plugin/plugin.properties
   [ -d pentaho-solutions ] && { pushd pentaho-solutions/system/kettle }
   pwd
   cp -f ~/pentaho/config.properties  plugins/pentaho-big-data-plugin/hadoop-configurations/$1/config.properties
   [ -d ../kettle ] && { popd }
   set +x
}

di_spark() {
   [ -d pentaho-solutions ] && { cd pentaho-solutions/system/kettle }
   export HADOOP_CONF_DIR=$(pwd)/plugins/pentaho-big-data-plugin/hadoop-configurations/$1
   [ -d ../kettle ] && { cd ../../.. }
   echo HADOOP_CONF_DIR=$HADOOP_CONF_DIR
}


function mfcat() {
  unzip -p "$1" META-INF/MANIFEST.MF | perl -0777 -wpe 's/\r?\n //g'
}


function install-pdi-client() {
  cd ~/pentaho
  rm -rf latest-minus-1
  mv latest latest-minus-1

  mkdir latest
  cd latest
  
  if [ -n "$1" ]; then
      export VERSION=$1
  else
      export VERSION="8.1-QAT"
  fi
  lftp  -e "pget $VERSION/latest/pdi-ee-client.zip;bye" -u anonymous,password build.pentaho.com
  unzip -q pdi-ee-client*
  cd data-integration
  sdbg
}


function install-spoon() {
    cd $PENTAHO_INSTALL_DIR
    if [ $1 = $SNAPSHOT_NAME ]; then
        export VERSION=$1
        export CI_SUBDIR=$1
    else
        export VERSION=$1-$2
        export CI_SUBDIR=$1/$2
    fi
    mkdir spoon
    cd spoon
    rm -rf $VERSION
    mkdir $VERSION
    cd $VERSION
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/$CI_SUBDIR/pdi-ee-client-$VERSION.zip
    unzip -q pdi-ee-client*
    # rm -f *.zip

    cd data-integration
#    ln -sf $(pwd) ~/pentaho/current-spoon
#    cd ~/pentaho/current-spoon
    sdbg
}

function install-x() {

    cd $PENTAHO_INSTALL_DIR

    if [ $1 = $SNAPSHOT_NAME ]; then
        export VERSION=$1
        export CI_SUBDIR=$1
    else
        export VERSION=$1-$2
        export CI_SUBDIR=$1/$2
    fi
    mkdir $3
    cd $3
    rm -rf $VERSION
    mkdir $VERSION
    cd $VERSION

    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/$CI_SUBDIR/$3-$VERSION.zip
    unzip -q *.zip
}



function install-pentaho-server() {

    cd $PENTAHO_INSTALL_DIR

    if [ $1 = $SNAPSHOT_NAME ]; then
        export VERSION=$1
        export CI_SUBDIR=$1
    else
        export VERSION=$1-$2
        export CI_SUBDIR=$1/$2
    fi
    rm -rf $VERSION
    mkdir $VERSION
    cd $VERSION

#    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/$CI_SUBDIR/biserver-ee-$VERSION.zip
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/$CI_SUBDIR/pentaho-server-ee-$VERSION.zip
    # fetch EE plugins
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/$CI_SUBDIR/paz-plugin-ee-$VERSION.zip
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/$CI_SUBDIR/pdd-plugin-ee-$VERSION.zip
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/$CI_SUBDIR/pentaho-mobile-plugin-$VERSION.zip
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/$CI_SUBDIR/pir-plugin-ee-$VERSION.zip
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/$CI_SUBDIR/pentaho-analysis-ee-$VERSION.zip


    
    unzip -q pentaho-server*
    unzip -q bi-server*

    unzip -q paz-plugin-ee-*.zip -d pentaho-server/pentaho-solutions/system
    unzip -q pdd-plugin-ee-*.zip -d pentaho-server/pentaho-solutions/system
    unzip -q pentaho-mobile-plugin-*.zip -d pentaho-server/pentaho-solutions/system
    unzip -q pir-plugin-ee-*.zip -d pentaho-server/pentaho-solutions/system

#    rm -f ~/pentaho/current-server
#    rm -f *.zip
    
    cd pentaho-server
    cp ~/dev/drivers/mysql-connector-java-5.1.22-bin.jar tomcat/lib

    ln -s $(pwd) ~/pentaho/current-server

    
    echo \
        org.pentaho.clean.karaf.cache=true >> pentaho-solutions/system/karaf/etc/custom.properties

    
    pd
}

function install-licenses() {
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/DEV_LICENSES/
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/DEV_LICENSES/Pentaho%20Analysis%20Enterprise%20Edition.lic
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/DEV_LICENSES/Pentaho%20BI%20Platform%20Enterprise%20Edition.lic
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/DEV_LICENSES/Pentaho%20Dashboard%20Designer.lic
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/DEV_LICENSES/Pentaho%20Hadoop%20Enterprise%20Edition.lic
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/DEV_LICENSES/Pentaho%20Mobile.lic
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/DEV_LICENSES/Pentaho%20PDI%20Enterprise%20Edition.lic
    wget --ftp-user=$BOX_USER --ftp-password=$BOX_PASS ftp://ftp.box.com/CI/DEV_LICENSES/Pentaho%20Reporting%20Enterprise%20Edition.lic

    # install dev licenses
    license-installer/install_license.sh install -q *.lic
}


function clean-pentaho-db() {
    ./stop-pentaho.sh
    sleep 2
    cd data/postgresql
    /Applications/Postgres.app/Contents/Versions/9.5/bin/psql -f create_jcr_postgresql.sql
    /Applications/Postgres.app/Contents/Versions/9.5/bin/psql -f create_repository_postgresql.sql
    /Applications/Postgres.app/Contents/Versions/9.5/bin/psql -f create_quartz_postgresql.sql
    /Applications/Postgres.app/Contents/Versions/9.5/bin/psql -f pentaho_mart_drop_postgresql.sql
    /Applications/Postgres.app/Contents/Versions/9.5/bin/psql -f pentaho_logging_postgresql.sql 
    /Applications/Postgres.app/Contents/Versions/9.5/bin/psql -f pentaho_mart_postgresql.sql
    ..2
}





# AEL stuff

server=cloudera@mayhem.local
diPath=/home/cloudera/pentaho/data-integration

function copyToServer() {
    
    scp  -P 2022 ~/dev/pentaho-ee/adaptive-execution/pdi-spark-app/pdi-spark-engine-operations/target/pdi-spark-engine-operations-8.1-SNAPSHOT.jar  ${server}:${diPath}/system/karaf/system/org/pentaho/adaptive/pdi-spark-engine-operations/8.1-SNAPSHOT
    scp  -P 2022 ~/dev/pentaho-ee/adaptive-execution/pdi-engines/pdi-engine-spark/target/pdi-engine-spark-8.1-SNAPSHOT.jar  ${server}:${diPath}/lib
    ssh cloudera@mayhem.local -p 2022 rm -rfv ${diPath}/system/karaf/caches
}


function updateSparkExecutor() {
    ssh  ${server} -p 2022 "cd pentaho;
         zip -ur pdi-spark-executor.zip data-integration;
         hdfs dfs -rm /tmp/pdi-spark-executor.zip;
         hdfs dfs -put pdi-spark-executor.zip /tmp"
}


function swap() {
    copyToServer
    updateSparkExecutor
}


function uploadFreshAEL() {

    scp -P 2022 $1 ${server}:${diPath}/..
    ssh  ${server} -p 2022 "cd pentaho;
         rm -rf data-integration;
         unzip  $1;
         cp -f application.properties data-integration/adaptive-execution/config"
    updateSparkExecutor

    
}
