#!/bin/bash

source ../.env
export PATH=$PATH:${PWD}/../bin
export FABRIC_CFG_PATH=${PWD}

# ---------------------------------------------------------------------------
# Clear screen
# ---------------------------------------------------------------------------
clear
echo "# ---------------------------------------------------------------------------"
echo "# Update Hostname"
echo "# ---------------------------------------------------------------------------"
sed -i "s/- node.hostname == .*/- node.hostname == $ORG3_HOSTNAME/g" ../org/docker-compose-org3.yml
sleep 2


echo
echo "# ---------------------------------------------------------------------------"
echo "# Generate crypto material for new Org"
echo "# ---------------------------------------------------------------------------"
cryptogen extend --config=crypto-config.yaml
if [ "$?" -ne 0 ]; then
  echo "Failed to generate crypto material..."
  exit 1
fi
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Create directories to copy crypto material for new Org"
echo "# ---------------------------------------------------------------------------"
mkdir -p /var/mynetwork/certs/crypto-config/peerOrganizations/org3.example.com
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Copy new crypto material for new Org"
echo "# ---------------------------------------------------------------------------"
cp -R crypto-config/peerOrganizations/org3.example.com/* /var/mynetwork/certs/crypto-config/peerOrganizations/org3.example.com/
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Print out the Org3-specific configuration material in JSON (org3.json)"
echo "# ---------------------------------------------------------------------------"
configtxgen -printOrg Org3MSP > org3.json
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Fetch the Configuration - protobuf"
echo "# Block #0: Genesis block"
echo "# Block #1: Update anchor peer : Org1"
echo "# Block #2: Update anchor peer : Org2"
echo "# Block #3: Instantiating chaincode: A=100,B=200"
echo "# Block #4: Invoking chaincode : Move 10 from A to B"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" peer channel fetch config config_block.pb -o "$ORDERER_NAME":7050 --tls --cafile $ORDERER_CA_LOCATION -c $CHANNEL_NAME
docker cp "$CLI_NAME":/opt/gopath/src/github.com/hyperledger/fabric/peer/config_block.pb ${PWD}/config_block.pb
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Convert the Configuration from protobuf to JSON (config.json)"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Add the Org3 Crypto Material (config.json + org3.json = modified_config.json)"
echo "# ---------------------------------------------------------------------------"
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"Org3MSP":.[1]}}}}}' config.json org3.json > modified_config.json
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Translate config.json back into a protobuf (config.pb)"
echo "# ---------------------------------------------------------------------------"
configtxlator proto_encode --input config.json --type common.Config --output config.pb
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Encode modified_config.json to modified_config.pb (modified_config.pb)"
echo "# ---------------------------------------------------------------------------"
configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Calculate the delta between these two config protobufs (config.pb + modified_config.pb = org3_update.pb)"
echo "# ---------------------------------------------------------------------------"
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output org3_update.pb
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Decode this object into editable JSON (org3_update.json)"
echo "# ---------------------------------------------------------------------------"
configtxlator proto_decode --input org3_update.pb --type common.ConfigUpdate | jq . > org3_update.json
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Wrap org3_update.json in an envelope message (org3_update_in_envelope.json)"
echo "# Add header field that we stripped away earlier"
echo "# ---------------------------------------------------------------------------"
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat org3_update.json)'}}}' | jq . > org3_update_in_envelope.json
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Convert org3_update_in_envelope.json into the fully fledged protobuf format (org3_update_in_envelope.json)"
echo "# ---------------------------------------------------------------------------"
configtxlator proto_encode --input org3_update_in_envelope.json --type common.Envelope --output org3_update_in_envelope.pb
docker cp org3_update_in_envelope.pb "$CLI_NAME":/opt/gopath/src/github.com/hyperledger/fabric/peer/org3_update_in_envelope.pb
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Sign and Submit the Config Update from Org 1"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" peer channel signconfigtx -f org3_update_in_envelope.pb
sleep 2

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Sign and Submit the Config Update from Org 2"
echo "# ---------------------------------------------------------------------------"
docker exec \
	-e "CORE_PEER_LOCALMSPID=Org2MSP" \
	-e "CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.crt" \
	-e "CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.key" \
	-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
	-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
	-e "CORE_PEER_ADDRESS=peer0.org2.example.com:7051" \
	"$CLI_NAME" peer channel update -f org3_update_in_envelope.pb -c $CHANNEL_NAME -o "$ORDERER_NAME":7050 --tls --cafile $ORDERER_CA_LOCATION
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Block height on Org 1"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" peer channel getinfo -c $CHANNEL_NAME
sleep 2

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Block height on Org 2"
echo "# ---------------------------------------------------------------------------"
docker exec \
	-e "CORE_PEER_LOCALMSPID=Org2MSP" \
	-e "CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.crt" \
	-e "CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.key" \
	-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
	-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
	-e "CORE_PEER_ADDRESS=peer0.org2.example.com:7051" \
	"$CLI_NAME" peer channel getinfo -c $CHANNEL_NAME
sleep 2

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Delete temporary files"
echo "# ---------------------------------------------------------------------------"
rm *.json *.pb
sleep 2 

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Deploy Org3 nodes"
echo "# ---------------------------------------------------------------------------"
docker stack deploy --compose-file ../org/docker-compose-org3.yml org3
sleep 5 

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Join channel : peer0.org3.example.com"
echo "# ---------------------------------------------------------------------------"
docker exec \
	-e "CORE_PEER_LOCALMSPID=Org3MSP" \
	-e "CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.crt" \
	-e "CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.key" \
	-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt" \
	-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp" \
	-e "CORE_PEER_ADDRESS=peer0.org3.example.com:7051" \
	"$CLI_NAME" peer channel join -b "$CHANNEL_NAME".block --tls --cafile $ORDERER_CA_LOCATION
sleep 2

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Join channel : peer1.org3.example.com"
echo "# ---------------------------------------------------------------------------"
docker exec \
	-e "CORE_PEER_LOCALMSPID=Org3MSP" \
	-e "CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer1.org3.example.com/tls/server.crt" \
	-e "CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer1.org3.example.com/tls/server.key" \
	-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer1.org3.example.com/tls/ca.crt" \
	-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp" \
	-e "CORE_PEER_ADDRESS=peer1.org3.example.com:7051" \
	"$CLI_NAME" peer channel join -b "$CHANNEL_NAME".block --tls --cafile $ORDERER_CA_LOCATION
sleep 2

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Installing new version of chaincode on org1"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" peer chaincode install -n "$CHAINCODE_NAME" -p "$CHAINCODE_SRC" -v $NEW_CHAINCODE_VERSION
sleep 2

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Installing new version of chaincode on org2"
echo "# ---------------------------------------------------------------------------"
docker exec \
	-e "CORE_PEER_LOCALMSPID=Org2MSP" \
	-e "CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.crt" \
	-e "CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.key" \
	-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
	-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
	-e "CORE_PEER_ADDRESS=peer0.org2.example.com:7051" \
	"$CLI_NAME" peer chaincode install -n "$CHAINCODE_NAME" -p "$CHAINCODE_SRC" -v $NEW_CHAINCODE_VERSION
sleep 2

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Installing new version of chaincode on org3"
echo "# ---------------------------------------------------------------------------"
docker exec \
	-e "CORE_PEER_LOCALMSPID=Org3MSP" \
	-e "CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.crt" \
	-e "CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.key" \
	-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt" \
	-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp" \
	-e "CORE_PEER_ADDRESS=peer0.org3.example.com:7051" \
	"$CLI_NAME" peer chaincode install -n "$CHAINCODE_NAME" -p "$CHAINCODE_SRC" -v $NEW_CHAINCODE_VERSION
sleep 10

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Check block height on Org 3"
echo "# ---------------------------------------------------------------------------"
docker exec \
	-e "CORE_PEER_LOCALMSPID=Org3MSP" \
	-e "CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.crt" \
	-e "CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.key" \
	-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt" \
	-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp" \
	-e "CORE_PEER_ADDRESS=peer0.org3.example.com:7051" \
	"$CLI_NAME" peer channel getinfo -c $CHANNEL_NAME
sleep 2

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Upgrade endorsement policy to include org3"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" peer chaincode upgrade -o "$ORDERER_NAME":7050 -C "$CHANNEL_NAME" -n "$CHAINCODE_NAME" "$CHAINCODE_SRC" -v $NEW_CHAINCODE_VERSION  -c '{"Args":["init","a", "90", "b","210"]}' -P "OR('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" --tls --cafile $ORDERER_CA_LOCATION
sleep 10 

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Invoking chaincode : Move 10 from A to B"
echo "# ---------------------------------------------------------------------------"
docker exec \
	-e "CORE_PEER_LOCALMSPID=Org3MSP" \
	-e "CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.crt" \
	-e "CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.key" \
	-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt" \
	-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp" \
	-e "CORE_PEER_ADDRESS=peer0.org3.example.com:7051" \
	"$CLI_NAME" peer chaincode invoke -o "$ORDERER_NAME":7050 --tls --cafile $ORDERER_CA_LOCATION -C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"Args":["move","a","b","10"]}'
sleep 5

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Query chaincode: Query A"
echo "# ---------------------------------------------------------------------------"
docker exec \
	-e "CORE_PEER_LOCALMSPID=Org3MSP" \
	-e "CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.crt" \
	-e "CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.key" \
	-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt" \
	-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp" \
	-e "CORE_PEER_ADDRESS=peer0.org3.example.com:7051" \
	"$CLI_NAME" peer chaincode query -o "$ORDERER_NAME":7050 --tls --cafile $ORDERER_CA_LOCATION -C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"Args":["query","a"]}'