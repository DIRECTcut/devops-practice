#!/bin/bash
# User data script for Amazon Linux 2023 EC2 instance

# Log all output
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "=== Starting user-data script at $(date) ==="

# Add SSH public key for the ec2-user
echo "Adding SSH public key..."
echo "${ssh_public_key}" >> /home/ec2-user/.ssh/authorized_keys
chmod 600 /home/ec2-user/.ssh/authorized_keys
chown ec2-user:ec2-user /home/ec2-user/.ssh/authorized_keys

# Configure SSH for port 2222
echo "Configuring SSH port 2222..."
# First, remove any existing Port lines to avoid duplicates
sed -i '/^Port /d' /etc/ssh/sshd_config
sed -i '/^#Port /d' /etc/ssh/sshd_config
# Add Port 2222 at the beginning of the file
sed -i '1i Port 2222' /etc/ssh/sshd_config

# Generate SSH host keys if they don't exist
echo "Generating SSH host keys..."
ssh-keygen -A

# Test SSH configuration before restart
echo "Testing SSH configuration..."
if sshd -t; then
    echo "SSH configuration is valid"
else
    echo "SSH configuration test failed!"
    cat /etc/ssh/sshd_config | head -20
    exit 1
fi

# Add the new port to SELinux if it's enabled
if command -v getenforce &> /dev/null && getenforce | grep -q "Enforcing"; then
    echo "Configuring SELinux for port 2222..."
    semanage port -a -t ssh_port_t -p tcp 2222 || semanage port -m -t ssh_port_t -p tcp 2222 || true
fi

# Restart SSH service
echo "Restarting SSH service..."
systemctl restart sshd

# Verify SSH is listening on port 2222
sleep 2
if ss -tlnp 2>/dev/null | grep -q :2222 || netstat -tlnp 2>/dev/null | grep -q :2222; then
    echo "SUCCESS: SSH is listening on port 2222"
else
    echo "WARNING: SSH may not be listening on port 2222"
    systemctl status sshd
fi

# Update the system
echo "Updating system packages..."
dnf update -y

# Install nginx
echo "Installing nginx..."
dnf install -y nginx

# Enable and start nginx
echo "Starting nginx..."
systemctl enable nginx
systemctl start nginx

# Log completion
echo "=== User data script completed at $(date) ==="#