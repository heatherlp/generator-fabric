@echo on
rem
rem Copyright IBM Corp All Rights Reserved
rem
rem SPDX-License-Identifier: Apache-2.0
rem

rem rewrite paths for Windows users to enable Docker socket binding
set COMPOSE_CONVERT_WINDOWS_PATHS=1

set CHANNEL_NAME=mychannel

rem teardown any existing network
cmd /c .\teardown.cmd

rem generate crypto material
docker run --rm -v %CD%:/etc/hyperledger/fabric -w /etc/hyperledger/fabric hyperledger/fabric-tools:1.4.1 cryptogen generate --config=./crypto-config.yaml

rem rename the certificate authority private key
move /y .\crypto-config\peerOrganizations\org1.example.com\ca\*_sk .\crypto-config\peerOrganizations\org1.example.com\ca\ca.org1.example.com-key.pem

rem start the certificate authority
docker-compose -f docker-compose.yml up -d ca.org1.example.com

rem enroll the admin identity
docker run --network <%= dockerName %>_basic --rm -v %CD%:/etc/hyperledger/fabric hyperledger/fabric-ca:1.4.1 fabric-ca-client enroll -u http://admin:adminpw@ca.org1.example.com:<%= certificateAuthority %> -M /etc/hyperledger/fabric/admin-msp
copy /y admin-msp\signcerts\cert.pem crypto-config\peerOrganizations\org1.example.com\msp\admincerts\
copy /y admin-msp\signcerts\cert.pem crypto-config\peerOrganizations\org1.example.com\peers\peer0.org1.example.com\msp\admincerts\

rem stop the certificate authority
docker-compose -f docker-compose.yml stop ca.org1.example.com

rem generate genesis block for orderer
docker run --rm -v %CD%:/etc/hyperledger/fabric -w /etc/hyperledger/fabric hyperledger/fabric-tools:1.4.1 configtxgen -profile OneOrgOrdererGenesis -outputBlock ./configtx/genesis.block

rem generate channel configuration transaction
docker run --rm -v %CD%:/etc/hyperledger/fabric -w /etc/hyperledger/fabric hyperledger/fabric-tools:1.4.1 configtxgen -profile OneOrgChannel -outputCreateChannelTx ./configtx/channel.tx -channelID %CHANNEL_NAME%

rem generate anchor peer transaction
docker run --rm -v %CD%:/etc/hyperledger/fabric -w /etc/hyperledger/fabric hyperledger/fabric-tools:1.4.1 configtxgen -profile OneOrgChannel -outputAnchorPeersUpdate ./configtx/Org1MSPanchors.tx -channelID %CHANNEL_NAME% -asOrg Org1MSP

rem generate gateways, nodes, and wallets
node generate.js

rem mark the process as complete
copy /y nul generate.complete