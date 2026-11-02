#!/bin/bash
export OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True
NAME="my-server"
echo "$SSH_PUBLIC_KEY" > /tmp/key.pub
CFGS=('{"ocpus":1,"memoryInGBs":6}' '{"ocpus":2,"memoryInGBs":12}')

for i in $(seq 1 100); do
  EXIST=$(oci compute instance list -c "$OCI_TENANCY" --display-name "$NAME" \
    --query 'data[?"lifecycle-state"!=`TERMINATED`].id' 2>/dev/null | grep -c "ocid1" || true)
  if [ "$EXIST" != "0" ]; then echo "Server exists, done."; exit 0; fi

  CFG="${CFGS[$(( (i-1) % 2 ))]}"
  echo "Attempt $i: $CFG $(date)"
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
    --display-name "$NAME" 2>&1) && { echo "SUCCESS ($CFG)"; echo "$OUT"; exit 0; }

  if echo "$OUT" | grep -qiE "capacity|TooManyRequests"; then
    echo "No capacity, waiting 5 min"; sleep 300; continue
  fi
  echo "$OUT"; exit 1
done