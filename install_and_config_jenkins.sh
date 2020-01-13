#!/bin/bash
# Update the YUM package.
sudo yum update -y

# Install Java.
sudo yum install -y java-1.8.0

# Download Jenkins.
sudo wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo

# Import a file key to enable installation from the Jenkins package.
sudo rpm --import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key

# Install Jenkins.
sudo yum install jenkins -y

# Change Jenkins' default port number, for security reasons.
sed -i '14s/8080/9090/' /etc/sysconfig/jenkins

# Start Jenkins.
jenkins_array=('start' 'enable' 'status')
for i in ${jenkins_array[@]}
do
    sudo service jenkins $i
done

# Go to the Jenkins control panel.
echo "http://" + "$(dig +short myip.opendns.com @resolver1.opendns.com)" + ":9090"

# Copy the initial admin password.
cat /var/lib/jenkins/secrets/initialAdminPassword
