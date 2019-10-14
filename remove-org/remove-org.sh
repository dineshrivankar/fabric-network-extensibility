#!/bin/bash

source ../.env
export PATH=$PATH:${PWD}/../bin
export FABRIC_CFG_PATH=${PWD}

# ---------------------------------------------------------------------------
# Clear screen
# ---------------------------------------------------------------------------
clear

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
echo "# Remove the Org3 Crypto Material (modified_config.json)"
echo "# ---------------------------------------------------------------------------"
jq 'del(.channel_group.groups.Application.groups.Org3MSP)' config.json > modified_config.json
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
echo "# Calculate the delta between these two config protobufs (config.pb + modified_config.pb = update.pb)"
echo "# ---------------------------------------------------------------------------"
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output update.pb
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Decode this object into editable JSON (update.json)"
echo "# ---------------------------------------------------------------------------"
configtxlator proto_decode --input update.pb --type common.ConfigUpdate | jq . > update.json
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Wrap update.json in an envelope message (update_in_envelope.json)"
echo "# Add header field that we stripped away earlier"
echo "# ---------------------------------------------------------------------------"
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat update.json)'}}}' | jq . > update_in_envelope.json
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Convert update_in_envelope.json into the fully fledged protobuf format (update_in_envelope.json)"
echo "# ---------------------------------------------------------------------------"
configtxlator proto_encode --input update_in_envelope.json --type common.Envelope --output update_in_envelope.pb
docker cp update_in_envelope.pb "$CLI_NAME":/opt/gopath/src/github.com/hyperledger/fabric/peer/update_in_envelope.pb
sleep 2

echo
echo "# ---------------------------------------------------------------------------"
echo "# Sign and Submit the Config Update from Org 1"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" peer channel signconfigtx -f update_in_envelope.pb
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
	"$CLI_NAME" peer channel update -f update_in_envelope.pb -c $CHANNEL_NAME -o "$ORDERER_NAME":7050 --tls --cafile $ORDERER_CA_LOCATION
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
echo "# Installing new version of chaincode on org1"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" peer chaincode install -n "$CHAINCODE_NAME" -p "$CHAINCODE_SRC" -v $NEW_CHAINCODE_VERSION_REMOVE_ORG
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
	"$CLI_NAME" peer chaincode install -n "$CHAINCODE_NAME" -p "$CHAINCODE_SRC" -v $NEW_CHAINCODE_VERSION_REMOVE_ORG
sleep 2

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Check block height"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" peer channel getinfo -c $CHANNEL_NAME
sleep 2

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Upgrade endorsement policy to remove org3"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" peer chaincode upgrade -o "$ORDERER_NAME":7050 -C "$CHANNEL_NAME" -n "$CHAINCODE_NAME" "$CHAINCODE_SRC" -v $NEW_CHAINCODE_VERSION_REMOVE_ORG  -c '{"Args":["init","a", "80", "b","220"]}' -P "OR('Org1MSP.member','Org2MSP.member')" --tls --cafile $ORDERER_CA_LOCATION
sleep 10 

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Invoking chaincode : Move 10 from A to B"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" peer chaincode invoke -o "$ORDERER_NAME":7050 --tls --cafile $ORDERER_CA_LOCATION -C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"Args":["move","a","b","10"]}'
sleep 5

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Query chaincode: Query A"
echo "# ---------------------------------------------------------------------------"
docker exec "$CLI_NAME" peer chaincode query -o "$ORDERER_NAME":7050 --tls --cafile $ORDERER_CA_LOCATION -C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"Args":["query","a"]}'

echo 
echo "# ---------------------------------------------------------------------------"
echo "# Query chaincode from org3: Query A - will fetch old value"
echo "# ---------------------------------------------------------------------------"
docker exec \
	-e "CORE_PEER_LOCALMSPID=Org3MSP" \
	-e "CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.crt" \
	-e "CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/server.key" \
	-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt" \
	-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp" \
	-e "CORE_PEER_ADDRESS=peer0.org3.example.com:7051" \
	"$CLI_NAME" peer chaincode query -o "$ORDERER_NAME":7050 --tls --cafile $ORDERER_CA_LOCATION -C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"Args":["query","a"]}'
	
echo 
echo "# ---------------------------------------------------------------------------"
echo "# Remove Org3 nodes"
echo "# ---------------------------------------------------------------------------"
docker stack rm org3
sleep 5 