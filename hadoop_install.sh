#! /bin/bash
# Author: Rohit LalChandani

set -e

# Global variable declartion, Change as per your need
USER_NAME='hadoop'
USER_PASS='chg2new'
HADOOP_LOCATION="/usr/local"
HADOOP_FILENAME="hadoop-0.20.203.0rc1.tar.gz"
HADOOP_VERSION="0.20.203.0"
HADOOP_DOWNLOAD="http://www.carfab.com/apachesoftware/hadoop/common/stable/$HADOOP_FILENAME"
HADOOP_COMMAND="hadoop"
totCols=`tput cols`
now=$(date +"%m-%d-%Y-%T")

MASTERIP=`cat hadoop_install.conf | grep master | cut -d ":" -f2`
SLAVECNT=`cat hadoop_install.conf | grep slave | cut -d ":" -f2 | tr "," "\n" | wc -l`
declare -a SLAVEIP
for (( c=1; c<=$SLAVECNT; c++ ))
do
	SLAVEIP[c]=`cat hadoop_install.conf | grep slave | cut -d ":" -f2 | cut -d ',' -f$c`
done

function hadoop_notes()
{
	echo "**********************************************************************************"
	echo "* You can log in to $USER_NAME user account and start hadoop services in 2 steps: *"
	echo "* Step 1. $HADOOP_LOCATION/hadoop/bin/start-dfs.sh                               *"
	echo "* Step 2. $HADOOP_LOCATION/hadoop/bin/start-mapred.sh                            *"
	echo "* To check if the hadoop server started: Type 'jps' (without quotes)             *"
	echo "* It will produce output something like this:                                    *"
	echo "* 10227 DataNode                                                                 *"
	echo "* 10680 Jps                                                                      *"
	echo "* 10495 JobTracker                                                               *"
	echo "* 10643 TaskTracker                                                              *"
	echo "* 10081 NameNode                                                                 *"
	echo "* 10374 SecondaryNameNode                                                        *"
	echo "* Please note that numbers above are process id(s), so it will/might             *"
	echo "* be different for you. Most important are the names which show                  *"
	echo "* that the following services are up and running.                                *"
	echo "* To stop the hadoop services, you need to follow the above 2 steps in reverse   *"
	echo "* order and replace start word with stop.                                        *"
	echo "* Thank you for using this script.                                               *"
	echo "* If you face any problem, please report to me at: admin@iredlof.com             *"
	echo "* Developed by: Rohit LalChandani                                                *"
	echo "* Homepage: http://iredlof.com                                                   *"
	echo "* Blog: http://blog.iredlof.com                                                  *"
	echo "* Courtesy: Thanks to Michael (http://www.michael-noll.com)                      *"
	echo "**********************************************************************************"
}

function check_sudo()
{
	if [ -z "$SUDO_USER" ]; then
		tput setf 4
		echo "$0 must be called as root. Try: 'sudo ${0}'"
		tput sgr0
		exit 1
	else
		sudo chmod 777 /tmp/hadoop_install.log
	fi
}

function printMsg()
{
	tput rev
	echo -ne $1
	str_len=`echo ${#1}`
	if [ `echo $(($totCols - $str_len - 6))` -gt 0 ]; then
		print_pos=`echo $(($totCols - $str_len - 6))`
	else
		print_pos=$str_len
	fi
	tput cuf $print_pos
	tput sgr0
}

function spinner()
{
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?} # #? is used to find last operation status code, in this case its 1
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"} # % is being used to delete the shortest possible matched string from right
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b[Done]\n"
}

function install_policy_kit()
{
	printMsg "Installing Policy Kit (Will skip if already installed)"
	if [ `apt-cache search '^policykit-1$' | wc -l` -eq 1 ] && [ `apt-cache policy policykit-1 | grep -i 'installed:' | grep '(none)' -i -c` -eq 1 ] ; then
		sudo apt-get -y install policykit-1 >> /tmp/hadoop_install.log 2>&1
	fi
}

function install_python_software_properties()
{
	printMsg "Installing Python Software Properties (Will skip if already installed)"
	if [ `apt-cache search '^python-software-properties$' | wc -l` -eq 1 ] && [ `apt-cache policy python-software-properties | grep -i 'installed:' | grep '(none)' -i -c` -eq 1 ] ; then
		sudo apt-get -y install python-software-properties >> /tmp/hadoop_install.log 2>&1
	fi
}

function install_java()
{
	printMsg "Installing Sun Java 6 JDK (Will skip if already installed)"
	if [ `apt-cache search '^sun-java6-jdk$' | wc -l` -eq 0 ] ; then
		sudo add-apt-repository -y ppa:ferramroberto/java >> /tmp/hadoop_install.log 2>&1
		sudo apt-get update >> /tmp/hadoop_install.log 2>&1
	fi
	if [ `apt-cache policy sun-java6-jdk | grep -i installed | grep '(none)' -i -c` -eq 1 ]; then
		sudo sh -c 'echo sun-java6-jdk shared/accepted-sun-dlj-v1-1 select true | /usr/bin/debconf-set-selections';
		sudo apt-get -y install sun-java6-jdk sun-java6-jre >> /tmp/hadoop_install.log 2>&1
		sudo update-java-alternatives -s java-6-sun >> /tmp/hadoop_install.log 2>&1
	fi
}

function add_user_group()
{
	printMsg "Adding $USER_NAME User/Group (Will skip if already exist)"
	if [ `grep -c $USER_NAME /etc/group` -eq 0 ]; then
		sudo addgroup $USER_NAME -q
	fi
	if [ `grep -c $USER_NAME /etc/passwd` -eq 0 ]; then
		sudo adduser --ingroup $USER_NAME $USER_NAME --disabled-login -gecos "Hadopp User" -q
		echo hadoop:$USER_PASS | sudo chpasswd
	else
		if [ `id $USER_NAME | egrep groups=[0-9]*'\($USER_NAME\)' -c` -eq 0 ]; then
			sudo usermod -a -G $USER_NAME $USER_NAME
		fi
	fi
}

function install_ssh()
{
	printMsg "Installing SSH Client (Will skip if already installed)"
	if [ `apt-cache search "^openssh-client$|^openssh-server$|^ssh$" | wc -l` -eq 3 ] && [ `apt-cache policy "^openssh-client$|^openssh-server$|^ssh$" | grep -i 'installed:' | grep -ic '(none)'` -gt 0 ]; then
		sudo apt-get -y install ssh >> /tmp/hadoop_install.log 2>&1
	fi
}

function ssh_configure()
{
	printMsg "Configuring SSH For $USER_NAME User (Will skip if RSA Key/Pair already exist)"
	if [ ! -f /home/$USER_NAME/.ssh/id_rsa ] && [ ! -f /home/$USER_NAME/.ssh/id_rsa.pub ]; then
		sudo pkexec --user $USER_NAME ssh-keygen -t rsa -P "" -f "/home/$USER_NAME/.ssh/id_rsa" -q
	fi

	#sudo pkexec --user $USER_NAME ssh-agent bash -c ssh-add -i /home/$USER_NAME/.ssh/id_rsa -q

	if [ ! -f /home/$USER_NAME/.ssh/authorized_keys ]; then
		sudo pkexec touch /home/$USER_NAME/.ssh/authorized_keys
	fi

	if [ `sudo pkexec --user hadoop grep $USER_NAME@\`hostname\` -c \/home\/$USER_NAME\/\.ssh\/authorized_keys` -eq 0 ]; then
		sudo cat /home/$USER_NAME/.ssh/id_rsa.pub >> /home/$USER_NAME/.ssh/authorized_keys
	    	sudo chown $USER_NAME:$USER_NAME /home/$USER_NAME/.ssh/authorized_keys
		sudo chmod 640 /home/$USER_NAME/.ssh/authorized_keys
	fi
	sudo pkexec --user $USER_NAME ssh -o StrictHostKeyChecking=no $USER_NAME@localhost exit >> /tmp/hadoop_install.log 2>&1
	if [[ "$1" = "m" ]]; then
		sudo pkexec --user $USER_NAME ssh -o StrictHostKeyChecking=no $USER_NAME@master exit >> /tmp/hadoop_install.log 2>&1
	else
		sudo pkexec --user $USER_NAME ssh -o StrictHostKeyChecking=no $USER_NAME@slave exit >> /tmp/hadoop_install.log 2>&1
	fi
}

function hadoop_download_test_files()
{
	printMsg "Downloading Test Data"
	if [ $USER == $USER_NAME ]; then
		
		if [ `jps | egrep -i 'NameNode|TaskTracker' -c` -lt 2 ]; then
			echo ''
			tput setf 4
			echo 'Error- Retry after starting hadoop system using option 5 from main menu'
			tput sgr0
			exit 1
		fi
		rm -r -f /tmp/gutenberg/
		mkdir /tmp/gutenberg

		wget -O /tmp/gutenberg/gutenberg1.txt http://www.gutenberg.org/ebooks/16399.txt.utf8
		wget -O /tmp/gutenberg/gutenberg2.txt http://www.gutenberg.org/ebooks/14900.txt.utf8
		wget -O /tmp/gutenberg/gutenberg3.txt http://www.gutenberg.org/ebooks/1452.txt.utf8
		wget -O /tmp/gutenberg/gutenberg4.txt http://www.gutenberg.org/ebooks/6693.txt.utf8
		wget -O /tmp/gutenberg/gutenberg5.txt http://www.gutenberg.org/ebooks/3233.txt.utf8
		wget -O /tmp/gutenberg/gutenberg6.txt http://www.gutenberg.org/ebooks/7937.txt.utf8
		wget -O /tmp/gutenberg/gutenberg7.txt http://www.gutenberg.org/ebooks/6886.txt.utf8
		wget -O /tmp/gutenberg/gutenberg8.txt http://www.gutenberg.org/ebooks/11772.txt.utf8
		wget -O /tmp/gutenberg/gutenberg9.txt http://www.gutenberg.org/ebooks/12539.txt.utf8
		wget -O /tmp/gutenberg/gutenberg10.txt http://www.gutenberg.org/ebooks/14297.txt.utf8
		
		# Deleting Old Test Files From HDFS With Name: gutenberg"
		if [ `$HADOOP_LOCATION/hadoop/bin/$HADOOP_COMMAND dfs -ls | grep -i -c gutenberg` -gt 0 ]; then
			$HADOOP_LOCATION/hadoop/bin/$HADOOP_COMMAND dfs -rmr gutenberg	>> /tmp/hadoop_install.log 2>&1
		fi

		# Copying Test Files To HDFS"	
		$HADOOP_LOCATION/hadoop/bin/$HADOOP_COMMAND dfs -copyFromLocal /tmp/gutenberg gutenberg
	else
		echo "[Error] Run from \"$USER_NAME\" user account."
	fi
}

function hadoop_start()
{
	printMsg "Starting Hadoop System"
	if [ $USER == $USER_NAME ]; then
		/usr/local/hadoop/bin/start-dfs.sh >> /tmp/hadoop_install.log 2>&1
		/usr/local/hadoop/bin/start-mapred.sh >> /tmp/hadoop_install.log 2>&1
	else
		"[Error] Run from \"$USER_NAME\" user account."
	fi
}

function hadoop_stop()
{
	printMsg "Stopping Hadoop System"
	if [ $USER == $USER_NAME ]; then
		/usr/local/hadoop/bin/stop-mapred.sh >> /tmp/hadoop_install.log 2>&1
		/usr/local/hadoop/bin/stop-dfs.sh >> /tmp/hadoop_install.log 2>&1
	else
		"[Error] Run from \"$USER_NAME\" user account."
	fi
}

function hadoop_format()
{
	printMsg "Formatting Hadoop File System"
	if [ $USER == $USER_NAME ]; then
		$HADOOP_LOCATION/hadoop/bin/$HADOOP_COMMAND namenode -format
	else
		echo "[Error] Run from \"$USER_NAME\" user account."
	fi
}

function run_test_job()
{
	printMsg "Executing Test Job"
	if [ `jps | egrep -i 'NameNode|TaskTracker' -c` -lt 2 ]; then
		echo ''
		tput setf 4
		echo 'Error- Retry after starting hadoop system using option 5 from main menu'
		tput sgr0
		exit 1
	fi
	if [ `$HADOOP_LOCATION/hadoop/bin/$HADOOP_COMMAND dfs -ls | grep -i -c gutenberg` -eq 0 ]; then
		echo ''
		tput setf 4
		echo 'Error- Retry after loading test data using option 7 from main menu'
		tput sgr0
		exit 1
	fi
	if [ `$HADOOP_LOCATION/hadoop/bin/$HADOOP_COMMAND dfs -ls | grep -i -c -w "gutenberg-output"` -gt 0 ]; then
		$HADOOP_LOCATION/hadoop/bin/$HADOOP_COMMAND dfs -rmr gutenberg-output	>> /tmp/hadoop_install.log 2>&1
	fi
	$HADOOP_LOCATION/hadoop/bin/$HADOOP_COMMAND jar $HADOOP_LOCATION/hadoop/hadoop*examples*.jar wordcount gutenberg gutenberg-output
}

function get_test_job_output()
{
	printMsg "Exporting Test Job Result"
	if [ `jps | egrep -i 'NameNode|TaskTracker' -c` -lt 2 ]; then
		echo ''
		tput setf 4
		echo 'Error- Retry after starting hadoop system using option 5 from main menu'
		tput sgr0
		exit 1
	fi
	if [ `$HADOOP_LOCATION/hadoop/bin/$HADOOP_COMMAND dfs -ls | grep -i -c gutenberg-output` -eq 0 ]; then
		echo ''
		tput setf 4
		echo 'Error- Retry after running test job using option 8 from main menu'
		tput sgr0
		exit 1
	fi
	rm -r -f /tmp/gutenberg-output
	$HADOOP_LOCATION/hadoop/bin/$HADOOP_COMMAND dfs -getmerge gutenberg-output /tmp/
}

function print_header()
{
	tput bold & tput setf 9 & tput smul
	str_len=`echo ${#1}`
	if [ `echo $(($totCols - $str_len - 6))` -gt 0 ]; then
		print_pos=`echo $(($totCols/2 - $str_len/2))`
	else
		print_pos=$str_len
	fi
	tput cuf $print_pos
	echo $1
	tput sgr0
	awk "BEGIN{for(c=0;c<$totCols;c++) printf \"-\"; printf \"\n\"}"
	echo ""
}

function print_error()
{
	tput bold & tput setf 4
	echo $1
	tput sgr0
}

function ipv6_file()
{
	if [[ "$1" = "a" ]]; then
		printMsg "Disabling IPv6"
	else
		printMsg "Reverting IPv6 Changes"
	fi
	sudo sed -i '/net\.ipv6\.conf\.all\.disable_ipv6/d;/net\.ipv6\.conf\.default\.disable_ipv6/d;/net\.ipv6\.conf\.lo\.disable_ipv6/d' /etc/sysctl.conf
	if [[ "$1" = "a" ]]; then
	    	sudo echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
		sudo echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
		sudo echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
	fi
}

function host_file()
{
	if [[ "$1" = "a" ]]; then
		printMsg "Adding Hadoop Cluster Mapping in Host File"
	else
		printMsg "Reverting Host File Changes"
	fi
	sudo sed -i '/Hadoop Master/Id;/Hadoop Slave/Id' /etc/hosts
	if [[ "$1" = "a" ]] ; then
		sudo echo -e "# Start: Hadoop Master/Slave Machines Configuration" >> /etc/hosts
		sudo echo -e "$MASTERIP\tmaster\t#Hadoop Master" >> /etc/hosts
		for (( c=1; c<=$SLAVECNT; c++ ))
		do
			echo -e "${SLAVEIP[$c]}\tslave$c\t#Hadoop Slave(s)" >> /etc/hosts
		done
		sudo echo -e "# End: Hadoop Master/Slave Machines Configuration" >> /etc/hosts
	fi
}

function bashrc_file()
{
	if [[ "$1" = "a" ]]; then
		printMsg "Adding Hadoop Environment Variables in $USER_NAME's .bashrc File"
	else
		printMsg "Reverting Hadoop Environment Variables Changes"
	fi
	sudo sed -i '/Hadoop/Id' /home/$USER_NAME/.bashrc
	if [[ "$1" = "a" ]] ; then
	    	sudo echo -e "# Start: Set Hadoop-related environment variables" >> /home/$USER_NAME/.bashrc
	    	sudo echo -e "export HADOOP_HOME=$HADOOP_LOCATION/hadoop\t#Hadoop Home Folder Path" >> /home/$USER_NAME/.bashrc
	    	sudo echo -e "export HADOOP_VERSION=$HADOOP_VERSION\t#Hadoop Version No" >> /home/$USER_NAME/.bashrc
	    	sudo echo -e "export PATH=\$PATH:\$HADOOP_HOME/bin\t#Add Hadoop bin/ directory to PATH" >> /home/$USER_NAME/.bashrc
		sudo echo -e "export JAVA_HOME=/usr/lib/jvm/java-6-sun\t#Java Path, Required For Hadoop" >> /home/$USER_NAME/.bashrc
		sudo echo -e "# End: Set Hadoop-related environment variables" >> /home/$USER_NAME/.bashrc
	fi
}

function hadoop_download()
{
	printMsg "Downloading Hadoop Tar (Will skip if $HADOOP_FILENAME is found in $HADOOP_LOCATION or `pwd` folder)"
	if [ ! -f $HADOOP_FILENAME ] && [ ! -f $HADOOP_LOCATION/$HADOOP_FILENAME ]; then
		wget -O /tmp/$HADOOP_FILENAME -c $HADOOP_DOWNLOAD >> /tmp/hadoop_install.log 2>&1
	fi
	if [ -f $HADOOP_FILENAME ]; then
		sudo mv /tmp/$HADOOP_FILENAME $HADOOP_LOCATION 	
	fi
}

function hadoop_setup()
{
	printMsg "Installing Hadoop (Installation Folder: $HADOOP_LOCATION/hadoop)"
	#Cleaning Old Installation
	sudo rm -f -r $HADOOP_LOCATION/`echo $HADOOP_FILENAME | sed "s/.tar.gz//g"`
	sudo rm -f -r $HADOOP_LOCATION/hadoop
	sudo rm -f -r /app
	sudo rm -f -r /tmp/hadoop_installation

	#Extracing Hadoop Files
	sudo mkdir /tmp/hadoop_installation
	sudo tar -xzf $HADOOP_LOCATION/$HADOOP_FILENAME -C /tmp/hadoop_installation

	#Renaming extracted folder to hadoop from `echo $HADOOP_FILENAME | sed "s/.tar.gz//g"` at $HADOOP_LOCATION
	sudo mv /tmp/hadoop_installation/hadoop* $HADOOP_LOCATION/hadoop
}

function hadoop_configure()
{
	printMsg "Configuring Hadoop (Installation Folder: $HADOOP_LOCATION/hadoop/)"
	
	if [[ "$1" = "m" ]]; then
		sudo echo "master" > $HADOOP_LOCATION/hadoop/conf/masters
		sudo rm -f -r $HADOOP_LOCATION/hadoop/conf/slaves
		for (( c=1; c<=$SLAVECNT; c++ ))
		do
			echo -e "slave$c" >> $HADOOP_LOCATION/hadoop/conf/slaves
		done
	fi

	#Setting JAVA_HOME environment variable for hadoop under $HADOOP_LOCATION/hadoop/conf/hadoop-env.sh file
	sudo sed "s/# export JAVA_HOME=\/usr\/lib\/j2sdk[1-9].[1-9]-sun/export JAVA_HOME=\/usr\/lib\/jvm\/java-6-sun/g" $HADOOP_LOCATION/hadoop/conf/hadoop-env.sh > /tmp/hadoop-env.sh.mod
	sudo mv /tmp/hadoop-env.sh.mod $HADOOP_LOCATION/hadoop/conf/hadoop-env.sh

	#Configuring $HADOOP_LOCATION/hadoop/conf/core-site.xml file for single node
	sudo sed "s/<configuration>/<configuration>\\`echo -e '\n\r'`\\`echo -e '\n\r'`<\!-- In: conf\/core-site.xml -->\\`echo -e '\n\r'`<property>\\`echo -e '\n\r'`	<name>hadoop.tmp.dir<\/name>\\`echo -e '\n\r'`	<value>\/app\/hadoop\/tmp<\/value>\\`echo -e '\n\r'`	<description>A base for other temporary directories\.<\/description>\\`echo -e '\n\r'`<\/property>\\`echo -e '\n\r'`<property>\\`echo -e '\n\r'`	<name>fs.default.name<\/name>\\`echo -e '\n\r'`	<value>hdfs\:\/\/master\:54310<\/value>\\`echo -e '\n\r'`	<description>The name of the default file system\. A URI whose\\`echo -e '\n\r'`	scheme and authority determine the FileSystem implementation\. The\\`echo -e '\n\r'`	uri\'s scheme determines the config property \(fs\.SCHEME\.impl\) naming\\`echo -e '\n\r'`	the FileSystem implementation class. The uri\'s authority is used to\\`echo -e '\n\r'`	determine the host\, port\, etc\. for a filesystem\.\\`echo -e '\n\r'`	<\/description>\\`echo -e '\n\r'`<\/property>/g" $HADOOP_LOCATION/hadoop/conf/core-site.xml > /tmp/core-site.xml.mod
	sudo mv /tmp/core-site.xml.mod $HADOOP_LOCATION/hadoop/conf/core-site.xml

	#Configuring $HADOOP_LOCATION/hadoop/conf/mapred-site.xml for single node
	sudo sed "s/<configuration>/<configuration>\\`echo -e '\n\r'`\\`echo -e '\n\r'`<\!-- In: conf\/mapred-site.xml -->\\`echo -e '\n\r'`<property>\\`echo -e '\n\r'`	<name>mapred\.job\.tracker<\/name>\\`echo -e '\n\r'`	<value>master\:54311<\/value>\\`echo -e '\n\r'`	<description>The host and port that the MapReduce job tracker runs\\`echo -e '\n\r'`	at\. If \"local\", then jobs are run in-process as a single map\\`echo -e '\n\r'`	and reduce task\.\\`echo -e '\n\r'`	<\/description>\\`echo -e '\n\r'`<\/property>/g" $HADOOP_LOCATION/hadoop/conf/mapred-site.xml > /tmp/mapred-site.xml.mod
	sudo mv /tmp/mapred-site.xml.mod $HADOOP_LOCATION/hadoop/conf/mapred-site.xml

	#Configuring $HADOOP_LOCATION/hadoop/conf/hdfs-site.xml for single node
	sudo sed "s/<configuration>/<configuration>\\`echo -e '\n\r'`\\`echo -e '\n\r'`<\!-- In: conf\/hdfs-site.xml -->\\`echo -e '\n\r'`<property>\\`echo -e '\n\r'`	<name>dfs\.replication<\/name>\\`echo -e '\n\r'`	<value>$SLAVECNT<\/value>\\`echo -e '\n\r'`	<description>Default block replication\.\\`echo -e '\n\r'`	The actual number of replications can be specified when the file is created\.\\`echo -e '\n\r'`	The default is used if replication is not specified in create time\.\\`echo -e '\n\r'`     <\/description>\\`echo -e '\n\r'`<\/property>/g" $HADOOP_LOCATION/hadoop/conf/hdfs-site.xml > /tmp/hdfs-site.xml.mod
	sudo mv /tmp/hdfs-site.xml.mod $HADOOP_LOCATION/hadoop/conf/hdfs-site.xml

	#Changing ownership of $HADOOP_LOCATION/hadoop folder to $USER_NAME user
	sudo chown -R $USER_NAME:$USER_NAME $HADOOP_LOCATION/hadoop
	sudo chmod -R 750 $HADOOP_LOCATION/hadoop

	#Creating /app/hadoop/tmp folder for hadoop file system and changing ownership to $USER_NAME user
	sudo mkdir -p /app/hadoop/tmp
	sudo chown -R $USER_NAME:$USER_NAME /app
	sudo chmod -R 750 /app
}

function install_hadoop()
{
	check_sudo
	clear
	print_header "Install Hadoop"
	echo -ne "Ques: Will this system be Master/Slave(m/s)? "
	read -n 1 nodeType
	nodeType=`echo $nodeType | tr '[:upper:]' '[:lower:]'`
	echo -e "\n"
	if [[ "$nodeType" = "m" ]] || [[ "$nodeType" = "s" ]]; then
		(install_policy_kit) & spinner $!
		(install_python_software_properties) & spinner $!
		(install_java) & spinner $!
		(add_user_group) & spinner $!
		(install_ssh) & spinner $!
		(ssh_configure "$nodeType") & spinner $!
		(ipv6_file "a") & spinner $!
		(host_file "a") & spinner $!
		(bashrc_file "a") & spinner $!
		(hadoop_download) & spinner $!
		(hadoop_setup) & spinner $!
		(hadoop_configure "$nodeType") & spinner $!
		tput setf 2
		echo "=> Hadoop installation complete";
		echo "=> Format hadoop filesystem using the below code:";
		tput sgr0
		tput setf 6
		echo "$HADOOP_LOCATION/hadoop/bin/$HADOOP_COMMAND namenode -format";
		tput sgr0
		if [ `cat /proc/sys/net/ipv6/conf/all/disable_ipv6` -eq 0 ]; then
			tput setf 6
			echo "=> Backup of /etc/sysctl.conf has been created as /etc/sysctl.conf.$now)";
			tput setf 4
	    		echo "=> Restarting system is RECOMMENDED";
			tput sgr0
		fi;
	else
		print_error "Incorrect input"
	fi
	echo -e "\nPress a key. . ."
	read -n 1	
}

function delete_hadoop_files()
{
	printMsg "Deleting Hadoop Folder ($HADOOP_LOCATION/hadoop/)"
	sudo rm -f -r $HADOOP_LOCATION/`echo $HADOOP_FILENAME | sed "s/.tar.gz//g"`
	sudo rm -f -r $HADOOP_LOCATION/hadoop
	sudo rm -f -r /app
	sudo rm -f -r /tmp/hadoop_installation	
}

function remove_hadoop()
{
	print_header "Uninstall Hadoop"
	read -n 1 -p "Are you sure (y/n)? " sure
	sure=`echo $sure | tr '[:upper:]' '[:lower:]'`
	echo -e "\n"
	if [[ "$sure" = 'y' ]]; then
		(ipv6_file "r") & spinner $!
		(host_file "r") & spinner $!
		(bashrc_file "r") & spinner $!
		(delete_hadoop_files) & spinner $!
		tput setf 6
		echo "Hadoop uninstallation complete"
		tput sgr0
	else
		tput setf 4
		echo "Hadoop uninstallation cancelled"
		tput sgr0
	fi
	echo -e "\nPress a key. . ."
	read -n 1
}

while :
  do
  clear
  echo "------------------------------------------------------"
  echo " * * * * * * * * * * Main Menu * * * * * * * * * * * *"
  echo " * Developed By: Rohit LalChandani                   *"
  echo " * * * * * * * * * * * * * * * * * * * * * * * * * * *"
  echo "------------------------------------------------------"
  echo "[1] Install Hadoop"
  echo "[2] Uninstall Hadoop"
  echo "[3] View Hadoop Help Notes"
  echo "[4] Exit (Slave/Master)"
  echo "------------------------------------------------------"
  echo "Current user account: $USER"
  echo -n "Enter your menu choice [1-4]: "
  read CHOICE
  case $CHOICE in
    1) clear; install_hadoop;;
    2) clear; remove_hadoop;;
    3) clear; hadoop_notes;;
    4) exit 0 ;;
    *) echo "Opps!!! Please select choice 1,2,3 or 4"
       echo "Press a key. . ."
       read -n 1
       ;;
  esac
done
