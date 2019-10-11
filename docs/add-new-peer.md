## Add New Peer
Adding new peer to exiting organisation on network is a simple 2 step process. First, we need to create new crypto material by extending the current material for org. Secondly, deploy the new peer with newly created crypto material and join the channel.
    
**# Step 1**

After successfully deploying the network, edit the “crypto-config.yaml” file to add new peer.
Change Org1 template count to 3

```bash
      - Name: Org1
        Domain: org1.example.com
        EnableNodeOUs: false
        Template:
           Count: 3
        Users:
          Count: 
```
 
**# Step 2**
Run the "add-new-peer.sh" script to perform below actions; 
1. Generate crypto material for new Peer.
2. Copy new crypto material to standard place for docker container.
3. Deploy new peers.
4. Join new peers to existing channel.
5. Check block height on new Peer.

```bash
    ./add-new-peer.sh
```

