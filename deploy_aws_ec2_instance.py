import boto3, os, subprocess, sys, time
from boto3.session import Session

def connect_to_aws():
    global ec2_resource, ec2_client, my_name, session

    my_name = os.getlogin()

    access_key = input("Enter your AWS access key: ")
    secret_key = input("Enter your AWS secret key: ")
    region = input("Enter an AWS region: ")

    session = Session(
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name=region
    )

    # Connect to the AWS EC2 service.
    ec2_resource = session.resource('ec2')
    ec2_client = session.client('ec2')

def create_ssh_key():
    global key_name

    print('Creating an SSH key.')

    key_filepath = "C:\\Users\\{}\\Downloads\\ssh_keys".format(my_name)
    key_name = input("Enter a name for your SSH key: ")

    aws_key = ec2_resource.create_key_pair(KeyName=key_name)
    local_key = str(aws_key.key_material)

    # Create a directory (if it does not exist) and a .pem file on the local machine.
    # Store the SSH key in the .pem file.
    if not os.path.exists(key_filepath):
        subprocess.Popen("mkdir {}".format(key_filepath),
                            shell=True,
                            stdout=subprocess.PIPE
        )
    local_key_file = open('{0}\\{1}.pem'.format(key_filepath, key_name), 'w')
    if not os.path.exists('{0}\\{1}.pem'.format(key_filepath, key_name)):
        local_key_file
    local_key_file.write(local_key)
    local_key_file.close()

def set_up_ec2_instance():
    global sec_group, subnet

    # Create a virtual private network.
    print('Creating a VPC.')
    vpc = ec2_resource.create_vpc(
        CidrBlock='192.168.0.0/16',
    )
    vpc.wait_until_available()

    # Create a virtual router and attach the VPN to it.
    print('Creating a virtual default gateway.')
    ig = ec2_resource.create_internet_gateway()
    vpc.attach_internet_gateway(InternetGatewayId=ig.id)

    # Create a route table and public route for the VPN.
    print('Creating a virtual route table.')
    route_table = vpc.create_route_table()
    route_table.create_route(
        DestinationCidrBlock='0.0.0.0/0',
        GatewayId=ig.id
    )

    # Create a subnet and attach it to the VPN.
    print('Creating a virtual subnet.')
    subnet = ec2_resource.create_subnet(
        CidrBlock='192.168.0.0/24',
        VpcId=vpc.id
    )

    # Associate the route table with the subnet.
    route_table.associate_with_subnet(SubnetId=subnet.id)

    # Create a security group and attach it to the VPN.
    print('Creating a virtual security group for the VPC.')
    sec_group = ec2_resource.create_security_group(
        GroupName='security_group',
        Description='A security group for the CentOS instance.',
        VpcId=vpc.id
    )

    # Create inbound firewall rules in the security group.
    # Permit HTTP and SSH traffic.
    print('Creating virtual firewall rules.')
    ec2_client.authorize_security_group_ingress(
        GroupId=sec_group.group_id,
        IpPermissions=[
            {
                'IpProtocol': 'tcp',
                'FromPort': 80,
                'ToPort': 80,
                'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
            },
            {
                'IpProtocol': 'tcp',
                'FromPort': 22,
                'ToPort': 22,
                'IpRanges': [{'CidrIp': '0.0.0.0/0'}]
            }
        ]
    )

def create_ec2_instance():
    global ec2_image

    server_name = input('Enter a name for the server: ')
    print('Creating the instance.')
    ec2_image = ec2_resource.create_instances(
        ImageId='ami-0f2b4fc905b0bd1f1',
        MinCount=1,
        MaxCount=1,
        KeyName=key_name,
        InstanceType='t2.medium',
        NetworkInterfaces=
        [
            {
                'DeviceIndex': 0,
                'SubnetId': subnet.id,
                'AssociatePublicIpAddress': True,
                'Groups': [sec_group.group_id]
            }
        ],
        TagSpecifications=[{
            'ResourceType': 'instance',
            'Tags': [{
                'Key'   : 'Name',
                'Value' : server_name
            }]
        }]
    )

def get_instance_info():
    print('Creating the public URL.')
    ec2_image[0].wait_until_running()
    ec2_image[0].reload()

    global instance_id

    public_ip = ec2_image[0].public_ip_address
    instance_id = ec2_image[0].instance_id
    
    print("URL: http://{0}/".format(public_ip))
    print('Instance ID: {0}'.format(instance_id))

def main():
    connect_to_aws()
    create_ssh_key()
    set_up_ec2_instance()
    create_ec2_instance()
    get_instance_info()

if __name__ == "__main__":
    main()
