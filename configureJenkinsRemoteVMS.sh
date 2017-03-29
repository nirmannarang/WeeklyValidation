#!/bin/bash -l

echo -en '#Configuring Jenkins VM and Remote Machines\n\n'

echo -en '#Setting Work Dir in installer.properties\n\n'
workdir=`pwd`
sed -i "s#workDir=.*#workDir=${workdir}#g" installer.properties
echo -en 'Work Directory of Jenkins VM is set to ' $workdir

echo -en '\n\n'
#sed -i '/workdir=/d' ./installer.properties
#echo -e '\nworkdir='${workdir}'\n' >> installer.properties

echo -en '#Configuring PPA and Installing Jenkins\n\n'
wget -q -O - https://pkg.jenkins.io/debian/jenkins-ci.org.key | sudo apt-key add -
sudo -S sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo -S apt-get update
sudo -S apt-get -y install jenkins

echo -en '#Waiting to get Jenkins service up after installation \n\n'
sleep 20s

echo -en '#Getting CLI jar\n\n'
rm -rf jenkins-cli.jar*
wget http://localhost:8080/jnlpJars/jenkins-cli.jar

echo -en '#Setting up number of Jenkins Executors as per installer.properties\n\n'
numExec=$(grep -Po '(?<=numExecutors=).*' installer.properties)
sed -i "/numExecutors/c\  <numExecutors>${numExec}</numExecutors>" /var/lib/jenkins/config.xml
echo -en 'Number of Executors set in Jenkins = ' $numExec '\n\n'

echo -en '#Removing useSecurity tag from Jenkins config.xml to remove authentication \n\n'
ex +g/useSecurity/d +g/authorizationStrategy/d -scwq /var/lib/jenkins/config.xml

sudo -S /etc/init.d/jenkins restart
echo -en 'Restarting Jenkins Service to make changes effective \n\n'
sleep 10s
#java -jar jenkins-cli.jar -noKeyAuth -s http://localhost:8080/ safe-restart
#echo -en '#Waiting to get Jenkins Server up after restart\n'
chmod +x triggerBaremetal

echo -en 'Configuring Remote Machines added in BaremetalMachines directory \n\n'
cd ${workdir}/baremetalMachines/
for filename in *; do
    cd ${workdir}/baremetalMachines/

    echo -en 'Configuring Machine ' ${filename} '\n\n'
    IPbaremetal=${filename}
    echo -en '\n\n'
    userName=$(grep -Po '(?<=userName=).*' ${filename})
    passWord=$(grep -Po '(?<=passWord=).*' ${filename})

    echo -en 'Copying WeeklyValidation to ' ${IPbaremetal} ' under User ' ${userName} '\n\n'
    scp -r ${workdir} ${userName}@${IPbaremetal}:

    echo -en 'ssh ' ${IPbaremetal} ' to user ' ${userName} '\n\n'
    ssh ${userName}@${IPbaremetal} /bin/bash <<'EOF'
    cd WeeklyValidation
    pwd
    workdirR=`pwd`
    #IPbaremetalR="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
    #IPbaremetalR=${ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'}
    IPbaremetalR=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
    userNameR=$(grep -Po '(?<=userName=).*' ${workdirR}/baremetalMachines/${IPbaremetalR})
    passWordR=$(grep -Po '(?<=passWord=).*' ${workdirR}/baremetalMachines/${IPbaremetalR})
   
    sed -i "s#USER_INSTALL_DIR=.*#USER_INSTALL_DIR=${workdirR}/IBMJAVA#g" installer.properties

    echo -en '#Downloading and installing jdk as per JDK_VAL in installer.properties file\n\n'
    jdk_val=$(grep -Po '(?<=JDK_VAL=).*' ${workdirR}/baremetalMachines/${IPbaremetalR})
    if [ ${jdk_val} = "OPENJDK" ]
    then
      if [ "$(. /etc/os-release; echo $NAME)" = "Ubuntu" ]; then
        echo -en 'Installing OPENJDK \n\n'
        echo ${passWordR} | sudo -S apt-get -y install openjdk-8-jdk
        echo -en 'Setting OpenJDK path and JAVA_HOME \n\n'
        export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-ppc64el
        export PATH=$JAVA_HOME/bin:$JAVA_HOME/jre/bin:$PATH
      else
        echo ${passWordR} | sudo -S yum install java-1.8.0-openjdk-devel
        export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
        export PATH=$JAVA_HOME/bin:$JAVA_HOME/jre/bin:$PATH
      fi
    elif [ ${jdk_val} = "IBMJDK" ]
    then
      echo -en 'Downloading and Installing IBM JDK \n\n'
      rm -rf ibm-java-ppc64le-sdk*
      rm -rf ibm-java-sdk*
      #wget http://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/8.0.3.22/linux/ppc64le/ibm-java-ppc64le-sdk-8.0-3.22.bin
      wget http://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/8.0.3.22/linux/ppc64le/ibm-java-sdk-8.0-3.22-ppc64le-archive.bin
      chmod +x ibm-java-sdk-8.0-3.22-ppc64le-archive.bin
      echo -en 'Installing IBMJDK as per the installation directory specified in installer.properties \n\n'
      echo ${passWordR} | sudo -S ./ibm-java-sdk-8.0-3.22-ppc64le-archive.bin -i silent -f installer.properties 1>console.txt 2>&1
      echo -en 'Setting IBMJDK path and JAVA_HOME \n\n'
      export JAVA_HOME=$(grep -Po '(?<=USER_INSTALL_DIR=).*' ${workdirR}/baremetalMachines/${IPbaremetalR})
      export PATH=$JAVA_HOME/bin:$JAVA_HOME/jre/bin:$PATH
    # JAVA_HOME
    #  echo 'pw4jenkins' | sudo -kS update-alternatives --install "/usr/bin/java" "java" "/opt/IBM/java/ibm_java_x86_64_80/" 1
    #  echo 'pw4jenkins' | sudo -kS chmod a+x /usr/bin/java
    else
      echo -en 'Please set the JDK correctly in config file and re-run \n\n'
      echo -en 'VALID OPTIONS are OPENJDK and IBMJDK and are case sensitive \n\n'
      exit 1
    fi
    export PATH=$JAVA_HOME/bin:$PATH

    if [ "$(. /etc/os-release; echo $NAME)" = "Ubuntu" ]; then
      echo -en '#Installing Git\n\n'
      #echo ${passWordR} | sudo -S update-alternatives --install
      echo ${passWordR} | sudo -S apt-get -y install git

      echo -en '#Installing R for sparkR-pkg\n\n'
      echo ${passWordR} | sudo -S apt-get -y install r-base-core

      echo -en '#Installing r-cran-testthat python-numpy python-scipy libblas-dev liblapack-dev python-dev python3-numpy python3-scipy python-dev gfortran libsnappy1 libsnappy-dev build-essential libstdc++6 \n\n'
      echo ${passWordR} | sudo -S apt-get update
      echo ${passWordR} | sudo -S apt-get -y install r-cran-testthat python-nose python-numpy python-scipy libblas-dev liblapack-dev python-dev python3-numpy python3-scipy python-dev gfortran libsnappy1v5 libsnappy-dev libsnappy1 build-essential libstdc++6 cython
    else
        #sudo -S vi /etc/yum/pluginconf.d/search-disabled-repos.conf
        #echo ${passWordR} | sudo -S yum -y update
        echo -en '#Installing Git\n\n'
        echo ${passWordR} | sudo -S yum -y install git

        echo -en '#Installing R for sparkR-pkg\n\n'
        echo ${passWordR} | sudo -S yum --assumeyes -y install R

        echo -en '#Installing numpy scipy gfortran snappy snappy-devel and build-essential tools \n\n'
        echo ${passWordR} | sudo -S yum -y groupinstall 'Development Tools'
        echo ${passWordR} | sudo -S yum -y install snappy snappy-devel zip r-cran-testthat numpy python34-devel python34-numpy python34-scipy python-devel scipy Cython
    fi

    echo -en '#Downloading and Installing Maven 3.3.9\n\n'
    rm -rf apache-maven-3.*
    #wget http://apache.mirrors.lucidnetworks.net/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz
    wget http://mirror.fibergrid.in/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz
    mkdir -p maven
    mv apache-maven-3.3.9-bin.tar.gz maven/
    cd maven/
    tar -xzvf apache-maven-3.3.9-bin.tar.gz
    echo -en '#Setting up Path for Maven \n\n'
    export M2_HOME=${workdirR}/maven/apache-maven-3.3.9
    export M2=$M2_HOME/bin
    export MAVEN_OPTS="-Xms512m -Xmx2048m"
    export PATH=$M2:$PATH

    echo -en '#Setting up Leveldb and Leveldbjni \n\n'
    cd ${workdirR}
    git clone https://github.com/ibmsoe/leveldbjni
    git clone https://github.com/ibmsoe/leveldb
    export SNAPPY_HOME=/usr/lib
    export LEVELDB_HOME=`cd leveldb; pwd`
    export LEVELDBJNI_HOME=`cd leveldbjni; pwd`
    cd ${LEVELDB_HOME}
    export LIBRARY_PATH=${SNAPPY_HOME}
    export C_INCLUDE_PATH=${LIBRARY_PATH}
    export CPLUS_INCLUDE_PATH=${LIBRARY_PATH}
    git apply ../leveldbjni/leveldb.patch
    make libleveldb.a
    cd ${LEVELDBJNI_HOME}
    mvn clean install -DskipTests -P download -Plinux64,all
    cd ${workdirR}

    echo -en 'Setting up OpenBLAS \n\n'
    git clone https://github.com/xianyi/OpenBLAS
    cd OpenBLAS
    make FC=gfortran
    make PREFIX=${workdirR}/openblas install
    echo -e "${workdirR}/openblas/lib" > openblas.conf
    echo ${passWordR} | sudo -S mv openblas.conf /etc/ld.so.conf.d/
    echo ${passWordR} | sudo -S ldconfig
EOF
done
exit 0
