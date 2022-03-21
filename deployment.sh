#Install dependencies
sudo apt-get update
sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg

#Install Microsoft signing key
curl -sL https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null

#Add the Azure CLI software repository
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" |
    sudo tee /etc/apt/sources.list.d/azure-cli.list
	
#Install
sudo apt-get update
sudo apt-get install azure-cli

#Login
az login --use-device-code

export ALGORAND_RESOURCE_GROUP=algorand-resource-group
export ALGORAND_LOCATION=WestEurope
export ALGORAND_VNET=algorand-vnet
export ALGORAND_DB_SUBNET=algorand-subnet-db
export ALGORAND_VM_SUBNET=algorand-subnet-vm
export DB_USER=algorandindexer
export DB_PASSWORD=xxxxxxx
export DB_NAME=algorand-indexer-db


#Set the default location
az configure --defaults location=$ALGORAND_LOCATION
#create resource group
az group create --name $ALGORAND_RESOURCE_GROUP
#Set default resource group
az configure --defaults group=$ALGORAND_RESOURCE_GROUP

#Create Postgres Database
az postgres flexible-server create --name algorand-indexer-flexible-server \
  --vnet $ALGORAND_VNET --subnet $ALGORAND_DB_SUBNET --address-prefixes 172.0.0.0/16 --subnet-prefixes 172.0.0.0/24\
  --admin-user $DB_USER --admin-password $DB_PASSWORD \
  --sku-name Standard_B1ms --tier Burstable --storage-size 1024  --tags "Billing=algorand" --version 13 \
  --database-name $DB_NAME --yes

#test connection
az postgres flexible-server connect --admin-user algorandindexer --name algorand-indexer-flexible-server

#create ssh key for the vm. the private key will be saved on the local computer under ~/.ssh/.
az sshkey create --name "algorand-key"

#create vm subnet
az network vnet subnet create --vnet-name $ALGORAND_VNET --address-prefixes 172.0.1.0/24 --name $ALGORAND_VM_SUBNET

#create vm
az vm create --name algorand-indexer-vm --image Canonical:UbuntuServer:18.04-LTS:latest \
  --admin-username algoranduser --ssh-key-name algorand-key \
  --size Standard_B2s --public-ip-address-allocation static \
  --subnet $ALGORAND_VM_SUBNET --vnet-name $ALGORAND_VNET \
  --custom-data ./install-indexer-binaries.yml


#connect to indexer node using ssh
ssh -i /home/megue/.ssh/<generated_ssh_private_key_path> algoranduser@<vm_ip_adress>

#Run indexer binaries
cd /home/algoranduser/indexer
./algorand-indexer daemon -P "host=algorand-indexer-flexible-server.postgres.database.azure.com port=5432 user=algorandindexer password=xxxxxx dbname=postgres sslmode=require" --algod-net="archive_node_url:archive_node_port" --algod-token="archive_node_token_access" --genesis [path_to_genesis_file]

