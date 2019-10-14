## Adding New Organization

**# Step 1**

Generate crypto material for new organization. kindly explore below files.
After generation of the artefacts, print out the new Org specific configuration material in JSON file (org3.json)

```bash
    new-org/configtx.yaml
    new-org/crypto-config.yaml
```

**# Step 2**

Update the network to include new org configuration. 
1.  Fetch the latest configuration block from ledger (config_block.pb)
2.  Convert the "config_block.pb" from protobuf to JSON (config.json), remove extra headers from the JSON.
3.  Add the new org crypto material to new JSON (config.json + org3.json = modified_config.json)
4.  Translate config.json back into a protobuf (config.pb)
5.  Encode modified_config.json to modified_config.pb (modified_config.pb)
6.  Calculate the delta between these two config protobufs (config.pb + modified_config.pb = org3_update.pb)
7.  Decode this object into editable JSON (org3_update.json)
8.  Wrap org3_update.json in an envelope message (org3_update_in_envelope.json).Add header field that we stripped away earlier.
9.  Convert org3_update_in_envelope.json into the fully fledged protobuf format (org3_update_in_envelope.json)
10. Org 1 & Org 2 will sign and submit the configuration update
 
**# Step 3**

Deploy new organization peers and join the existing channel.

**# Step 4**

Perform chaincode operation by installing new version of chaincode and upgrade endorsement policy to include new org.


Below script will automate all the above processes.
```bash
     cd new-org/
     ./deploy.sh
```

