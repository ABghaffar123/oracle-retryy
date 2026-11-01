#!/bin/bash
NAME="my-server"
echo "$SSH_PUBLIC_KEY" > /tmp/key.pub

COUNT=$(oci compute instance list -c "$OCI_TENANCY" --display-name "$NAME" \
  --query 'data[?"lifecycle-state"!=`TERMINATED`] | length(@)' --raw-output)
if [ "$COUNT" != "0" ]; then echo "Server already exists, done."; exit 0; fi

CFG='{"ocpus":2,"memoryInGBs":12}'
echo "Trying $CFG"
OUT=$(oci compute instance launch \
  --compartment-id "$OCI_TENANCY" \
  --availability-domain "$OCI_AD" \
  --shape VM.Standard.A1.Flex \
  --shape-config "$CFG" \
  --image-id "$OCI_IMAGE" \
  --subnet-id "$OCI_SUBNET" \
  --assign-public-ip true \
  --boot-volume-size-in-gbs 200 \
  --ssh-authorized-keys-file /tmp/key.pub \
  --display-name "$NAME" 2>&1) && { echo "SUCCESS"; echo "$OUT"; exit 0; }

if echo "$OUT" | grep -qiE "capacity|TooManyRequests"; then
  echo "No capacity, will retry next run."; exit 0
fi
echo "$OUT"; exit 1