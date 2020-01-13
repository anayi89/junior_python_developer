# Login to your Azure account.
Login-AzAccount

# Assign variables.
$ResourceGroupName    = 'test-rg'
$Location             = 'eastus'
$SubnetName           = 'test-net'
$VirtualNetworkName   = 'test-vnet'
$NetworkSecurityGroup = 'test-nsg'
$AllowedPorts         = 22, 80, 443
$OSType               = 'Linux'
$VMName               = 'test-vm'
$VMSize               = 'Standard_A2'
$VMSKU                = 'Standard'
# The supplied password must be between 6-72 characters long and must satisfy at least 3 of password
# complexity requirements from the following:
# 1) Contains an uppercase character
# 2) Contains a lowercase character
# 3) Contains a numeric digit
# 4) Contains a special character
# 5) Control characters are not allowed
$VMUser               = 'vmuser'
$VMCredential         = Get-Credential -Message 'Please enter a password for the virtual machine.' -UserName $VMUser

# Create a resource group.
Write-Host 'Creating a resource group.'
$ResourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location

# Create inbound network security group rules.
Write-Host 'Creating firewall rules.'
[System.Array] $NsgRules = @()
[int] $Priority = 1000
foreach ($Port in $AllowedPorts)
{
    $Rule = New-AzNetworkSecurityRuleConfig -Name "Allow_$Port" -Protocol Tcp `
        -Direction Inbound -Priority $Priority -SourceAddressPrefix * -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange $Port -Access Allow
    $Priority++
    $NsgRules += $Rule
}

# Create a network security group.
Write-Host 'Creating a network security group.'
$NSG = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroup.ResourceGroupName `
    -Location $Location -Name $NetworkSecurityGroup -SecurityRules $NsgRules

# Create the subnets and associate them with the network security group.
Write-Host 'Creating the subnets.'
$SubnetName1 = "$($SubnetName + '1')"
$SubnetName2 = "$($SubnetName + '2')"
$SubnetConfig1 = New-AzVirtualNetworkSubnetConfig -Name $SubnetName1 `
    -AddressPrefix '192.168.1.0/24' -NetworkSecurityGroup $NSG
$SubnetConfig2 = New-AzVirtualNetworkSubnetConfig -Name $SubnetName2 `
    -AddressPrefix '192.168.2.0/24' -NetworkSecurityGroup $NSG

# Create a virtual network.
Write-Host 'Creating a virtual network.'
$VNet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroup.ResourceGroupName `
    -Location $Location -Name $VirtualNetworkName -AddressPrefix '192.168.0.0/16' `
    -Subnet $SubnetConfig1,$SubnetConfig2

# Create a public IP address.
Write-Host 'Creating a public IP address.'
$PipName = $VMName + '-pip-' + $(Get-Random).ToString()
$PublicIP = New-AzPublicIpAddress -ResourceGroupName $ResourceGroup.ResourceGroupName `
    -Location $Location -Name $PipName -AllocationMethod 'static' -IdleTimeoutInMinutes 4 -Sku $VMSKU

# Create a virtual NIC and associate it with the public IP address.
Write-Host 'Creating a virtual NIC.'
$NICNum = $(Get-Random).ToString()
$NICName = "$($VMName + "-nic-" + $NICNum)"
$Subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName1 -VirtualNetwork $VNet
$NICIPConfig = New-AzNetworkInterfaceIpConfig -Name "IPConfig1" -PrivateIpAddressVersion IPv4 `
    -PrivateIpAddress "192.168.1.100" -SubnetId $Subnet.Id
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroup.ResourceGroupName `
    -Location $Location -IpConfiguration $NICIPConfig
$NIC | Set-AzNetworkInterfaceIpConfig -Name $NICIPConfig.Name -PublicIPAddress $PublicIP -Subnet $VNet.Subnets[0]
$NIC | Set-AzNetworkInterface

# Select the type of Operating System.
Write-Host 'Selecting a virtual operating system.'
[hashtable] $VMSourceImage = @{PublisherName='';Offer='';Sku=''}
switch ($OSType) {
    'Windows' {
        $VMSourceImage.PublisherName = 'MicrosoftWindowsServer'
        $VMSourceImage.Offer = 'WindowsServer'
        $VMSourceImage.Sku = '2019-Datacenter'
    }
    'Linux'{
        $VMSourceImage.PublisherName = 'OpenLogic'
        $VMSourceImage.Offer = 'CentOS'
        $VMSourceImage.Sku = '7.5'
    }
}

# Create the virtual machine's configuration.
Write-Host 'Configuring the virtual machine.'
$VMConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize 
if ($OSType -eq 'Windows')
{
    $VMConfig | Set-AzVMOperatingSystem -Windows -ComputerName $VMName -Credential $VMCredential | Out-Null
}
else 
{
    $VMConfig | Set-AzVMOperatingSystem -Linux -ComputerName $VMName -Credential $VMCredential | Out-Null
}
$VMConfig | Set-AzVMSourceImage -PublisherName $VMSourceImage.PublisherName `
    -Offer $VMSourceImage.Offer -Skus $VMSourceImage.Sku -Version latest | Out-Null
$VMConfig | Add-AzVMNetworkInterface -Id $NIC.Id | Out-Null
$VMConfig | Set-AzVMBootDiagnostic -Disable | Out-Null

# Create the virtual machine.
Write-Host 'Creating the virtual machine.'
New-AzVM -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $Location -VM $VMConfig
Get-AzVM -ResourceGroupName $ResourceGroup.ResourceGroupName

# Connect to the virtual machine.
$VMIPAddress = (Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup.ResourceGroupName).IpAddress
$SSHAddress = $VMUser + '@' + $VMIPAddress
ssh $SSHAddress
