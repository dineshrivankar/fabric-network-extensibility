#!/bin/bash

source .env
export PATH=$PATH:${PWD}/../bin
export FABRIC_CFG_PATH=${PWD}

# ---------------------------------------------------------------------------
# Clear screen
# ---------------------------------------------------------------------------
clear


OPTION=$1
CONSENSUS_TYPE=$2

echo "# ---------------------------------------------------------------------------"
echo "# Update Hostname"
echo "# ---------------------------------------------------------------------------"
sed -i "s/- node.hostname == .*/- node.hostname == $ORG1_HOSTNAME/g" org/docker-compose-org1-new-peer.yml
sleep 2


echo
echo "# ---------------------------------------------------------------------------"
echo "# Generate crypto material for new Peer"
echo "# ---------------------------------------------------------------------------"
cryptogen extend --config=crypto-config.yaml
if [ "$?" -ne 0 ]; then
  echo "Failed to generate crypto material..."
  exit 1
fi
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Create directories to copy crypto material for new Peer"
echo "# ---------------------------------------------------------------------------"
mkdir -p /var/mynetwork/certs/crypto-config/peerOrganizations/org1.example.com/peers/peer2.org1.example.com
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Copy new crypto material for new Peer"
echo "# ---------------------------------------------------------------------------"
cp -R crypto-config/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/* /var/mynetwork/certs/crypto-config/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/
sleep 2

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Deploy new peer for Org1"
echo "# ---------------------------------------------------------------------------"
docker stack deploy --compose-file org/docker-compose-org1-new-peer.yml org1
sleep 5 

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Join channel : peer2.org1.example.com"
echo "# ---------------------------------------------------------------------------"
docker exec \
	-e "CORE_PEER_LOCALMSPID=Org1MSP" \
	-e "CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/tls/server.crt" \
	-e "CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/tls/server.key" \
	-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/tls/ca.crt" \
	-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
	-e "CORE_PEER_ADDRESS=peer2.org1.example.com:7051" \
	"$CLI_NAME" peer channel join -b "$CHANNEL_NAME".block --tls --cafile $ORDERER_CA_LOCATION
sleep 10

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Check block height on old Peer (Peer0)"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" peer channel getinfo -c $CHANNEL_NAME
sleep 2

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Check block height on new Peer (Peer1)"
echo "# ---------------------------------------------------------------------------"
docker exec \
	-e "CORE_PEER_LOCALMSPID=Org1MSP" \
	-e "CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/tls/server.crt" \
	-e "CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/tls/server.key" \
	-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/tls/ca.crt" \
	-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
	-e "CORE_PEER_ADDRESS=peer2.org1.example.com:7051" \
	"$CLI_NAME" peer channel getinfo -c $CHANNEL_NAME
sleep 2
