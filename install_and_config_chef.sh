#!/bin/bash
# Update the YUM repository.
sudo yum update -y

# Install Wget.
sudo yum install -y wget

# Download Chef.
sudo wget https://packages.chef.io/files/stable/chef-server/13.1.13/el/7/chef-server-core-13.1.13-1.el7.x86_64.rpm

# Install Chef.
mv chef-server-core-13.1.13-1.el7.x86_64.rpm /tmp
sudo rpm -Uvh /tmp/chef-server-core-13.1.13-1.el7.x86_64.rpm

# Start Chef.
sudo chef-server-ctl reconfigure --chef-license=accept

# Create an admin account for Chef.
echo "Enter a username for your Chef account: "
read chef_user

echo "Enter a password for your Chef account: "
read -s chef_pass

echo "Enter your first name: "
read chef_first

echo "Enter your last name: "
read chef_last

echo "Enter your email address: "
read chef_email

echo "Enter a name for your RSA key: "
read chef_key
sudo mkdir ~/chef_keys

sudo chef-server-ctl user-create $chef_user $chef_first $chef_last $chef_email $chef_pass --filename '~/chef_keys/${chef_key}.pem'

# Create an organization in Chef.
echo "Enter the name of your organization: "
read chef_org_long

echo "Enter a shortened version of the name of your organization: "
read chef_org_short

#org_key = ${chef_key%/*}/ + $chef_org_short + '-validator.pem'

sudo chef-server-ctl org-create $chef_org_short $chef_org_long --association_user $chef_user --filename '~/chef_keys/${org_key}-validator.pem'

# Install Chef Manage.
sudo chef-server-ctl install chef-manage

# Restart Chef.
sudo chef-server-ctl reconfigure

# Restart Chef Manage.
sudo chef-manage-ctl reconfigure --accept-license

# Install Chef Workstation
wget https://packages.chef.io/files/stable/chef-workstation/0.13.35/el/7/chef-workstation-0.13.35-1.el7.x86_64.rpm
sudo rpm -ivh chef-workstation-0.13.35-1.el7.x86_64.rpm
chef env --chef-license=accept

# Install Chef Gem for Azure
export PATH="/home/vmuser/.chefdk/gem/ruby/2.6.0/bin:$PATH"
chef gem install knife-azure --pre
