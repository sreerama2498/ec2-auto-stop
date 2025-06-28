#!/bin/bash

# === CONFIGURATION ===
BUCKET_NAME="ec2-approval-bucket"
YES_FILE="yes.txt"
TMP_FILE="/tmp/user_response.txt"
INSTANCE_ID="i-03a5dc2c4f355a1e7"   # <-- Replace this!
REGION="ap-south-1"

# SES Email Setup
TO_EMAIL="kishorragipati@gmail.com"
FROM_EMAIL="sreeramragipati@gmail.com"
YES_URL="https://ec2-approval-bucket.s3.ap-south-1.amazonaws.com/yes.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAWOHV5XBDSDPDYLVL%2F20250627%2Fap-south-1%2Fs3%2Faws4_request&X-Amz-Date=20250627T131009Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Signature=40bfb79f1e9cec69a525abc175e9732445536d408f25ce6d8489d7a0ebf8170f"
NO_URL="https://ec2-approval-bucket.s3.ap-south-1.amazonaws.com/no.txt?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAWOHV5XBDSDPDYLVL%2F20250627%2Fap-south-1%2Fs3%2Faws4_request&X-Amz-Date=20250627T131021Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&X-Amz-Signature=4d8745d059f951e79048c8a51f2d5a23487aae01391e06bf8c9dc61148d84853"

# === STEP 1: CPU Check using top ===
cpu_idle=$(top -bn1 | grep "%Cpu(s)" | awk '{print $8}' | cut -d'.' -f1)
cpu_usage=$((100 - cpu_idle))

echo "[INFO] CPU Usage: $cpu_usage%"

# === STEP 2: If CPU usage is <5% or >95%, send email
if [[ $cpu_usage -lt 5 || $cpu_usage -gt 95 ]]; then
    echo "[ALERT] CPU usage $cpu_usage% - Sending approval email..."

    SUBJECT="⚠️ EC2 Instance CPU at $cpu_usage% - Approve Stop?"
    BODY="Your EC2 instance ($INSTANCE_ID) is currently using $cpu_usage% CPU.

Click to take action:
✅ YES (Stop Instance): $YES_URL
❌ NO (Keep Running): $NO_URL

- Automation Bot"

    aws ses send-email \
      --region $REGION \
      --from "$FROM_EMAIL" \
      --destination "ToAddresses=$TO_EMAIL" \
      --message "Subject={Data='$SUBJECT'},Body={Text={Data='$BODY'}}"
else
    echo "[OK] CPU is normal. No action required."
    exit 0
fi

# === STEP 3: Wait 3 minutes for user to click YES/NO
echo "[INFO] Waiting for user approval..."
sleep 180

# === STEP 4: Download YES.txt and check user response
aws s3 cp s3://$BUCKET_NAME/$YES_FILE $TMP_FILE --region $REGION
approval_value=$(cat $TMP_FILE | tr -d '\r\n')

echo "[INFO] User response from S3: $approval_value"

# === STEP 5: If approved, stop EC2 and reset
                                                                                                                                                                                                1,1           Top
if [[ "$approval_value" == "YES" ]]; then
    echo "[ACTION] Stopping EC2 instance..."
    aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION

    echo "NO" > $TMP_FILE
    aws s3 cp $TMP_FILE s3://$BUCKET_NAME/$YES_FILE --region $REGION
    echo "[DONE] EC2 stopped. Approval reset to NO."
else
    echo "[INFO] No approval or rejected. No action taken."
fi

