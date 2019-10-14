## Remove Organization

**# Step 1**

Removing organization for network requires updates to the existing channels, the organization should be released from all the channels and polices.

Update the network to remove new org.
 
1.  Fetch the latest configuration block from ledger (config_block.pb)
2.  Convert the "config_block.pb" from protobuf to JSON (config.json), remove extra headers from the JSON.
3.  Remove org crypto material to new JSON (config.json = modified_config.json)
4.  Translate config.json back into a protobuf (config.pb)
5.  Encode modified_config.json to modified_config.pb (modified_config.pb)
6.  Calculate the delta between these two config protobufs (config.pb + modified_config.pb = update.pb)
7.  Decode this object into editable JSON (update.json)
8.  Wrap update.json in an envelope message (update_in_envelope.json).Add header field that we stripped away earlier.
9.  Convert update_in_envelope.json into the fully fledged protobuf format (update_in_envelope.json)
10. Org 1 & Org 2 will sign and submit the configuration update
 
**# Step 2**

Perform chaincode operation by installing new version of chaincode and upgrade endorsement policy to remove new org.

**# Step 3**

Remove organization peers.



Below script will automate all the above processes.
```bash
     cd remove-org/
     ./remove-org.sh
```
 
