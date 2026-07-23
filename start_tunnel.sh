#!/bin/bash
# start_tunnel.sh
# Run this on your local machine (Mac) after turning on the WiJungle VPN.
# It forwards remote port 2222 on the Hostinger server back to the client's SFTP server.

REMOTE_USER="u156958239"
REMOTE_HOST="147.93.109.38"
REMOTE_PORT="65002"

# Replace the values below with the actual host/port of your client's SFTP server
SFTP_SERVER="sftp.client-server.com"
SFTP_PORT="22"

echo "--------------------------------------------------------"
echo "🔌 Starting SSH Reverse Port Forwarding Tunnel..."
echo "🔗 Local client VPN must be active (WiJungle)."
echo "📡 Traffic sent to Hostinger port 2222 will be forwarded to:"
echo "   $SFTP_SERVER:$SFTP_PORT"
echo "--------------------------------------------------------"
echo "Starting tunnel... (Press Ctrl+C to close)"

ssh -o StrictHostKeyChecking=no -p $REMOTE_PORT -N -R 2222:$SFTP_SERVER:$SFTP_PORT $REMOTE_USER@$REMOTE_HOST
