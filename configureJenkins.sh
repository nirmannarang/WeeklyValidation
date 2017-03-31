#!/bin/bash -l

echo -en '#Configuring Jenkins VM and Remote Machines\n\n'

echo -en '#Setting Work Dir in installer.properties\n\n'
workdir=`pwd`
sed -i "s#workDir=.*#workDir=${workdir}#g" installer.properties
echo -en 'Work Directory of Jenkins VM is set to ' $workdir

sed -i "s#workDir=.*#workDir=${workdir}#g" ConfigureRemoteMachines.xml

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
chmod +x createJobs

exit 0
