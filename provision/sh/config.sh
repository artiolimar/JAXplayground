#!/bin/bash
set -e

## update the list of hosts
sudo sh -c "echo '127.0.0.1 localhost\n127.0.1.1 vagrant\n' > /etc/hosts"
sudo sh -c "cat /vagrant/hosts.list >> /etc/hosts"

## passwordless ssh config
readarray -t NODES < /vagrant/hostnames.list
echo "Cluster nodes: ${NODES[*]}"

USER="vagrant"
HOME_DIR="/home/$USER"
SSH_DIR="$HOME_DIR/.ssh"
SHARED_KEY_PRIVATE="/vagrant/mpi_key"
SHARED_KEY_PUBLIC="/vagrant/mpi_key.pub"

# ensure .ssh directory exists with proper permissions
mkdir -p "$SSH_DIR"
chown "$USER:$USER" "$SSH_DIR"
chmod 700 "$SSH_DIR"

# create or reuse shared keypair
if [ ! -f "$SHARED_KEY_PRIVATE" ]; then
    echo "Generating shared MPI SSH keypair in /vagrant..."
    sudo -u "$USER" ssh-keygen -t rsa -N "" -f "$SHARED_KEY_PRIVATE"
else
    echo "Reusing existing shared MPI SSH keypair from /vagrant."
fi

# install shared keypair as user's identity
cp "$SHARED_KEY_PRIVATE" "$SSH_DIR/id_rsa"
cp "$SHARED_KEY_PUBLIC" "$SSH_DIR/id_rsa.pub"
chown "$USER:$USER" "$SSH_DIR/id_rsa" "$SSH_DIR/id_rsa.pub"
chmod 600 "$SSH_DIR/id_rsa"
chmod 644 "$SSH_DIR/id_rsa.pub"

# add shared public key to authorized_keys
if [ ! -f "$SSH_DIR/authorized_keys" ]; then
    touch "$SSH_DIR/authorized_keys"
    chown "$USER:$USER" "$SSH_DIR/authorized_keys"
    chmod 600 "$SSH_DIR/authorized_keys"
fi

PUBKEY_CONTENT=$(cat "$SHARED_KEY_PUBLIC")
if ! grep -q "$PUBKEY_CONTENT" "$SSH_DIR/authorized_keys"; then
    echo "Adding shared MPI public key to authorized_keys..."
    echo "$PUBKEY_CONTENT" >> "$SSH_DIR/authorized_keys"
fi

# pre-populate known_hosts for all nodes
echo "Populating known_hosts..."
KNOWN_HOSTS_FILE="$SSH_DIR/known_hosts"
touch "$KNOWN_HOSTS_FILE"
chown "$USER:$USER" "$KNOWN_HOSTS_FILE"
chmod 644 "$KNOWN_HOSTS_FILE"

for HOST in "${NODES[@]}"; do
    # remove any existing entry to avoid duplicates
    ssh-keygen -R "$HOST" -f "$KNOWN_HOSTS_FILE" >/dev/null 2>&1 || true
    sudo -u "$USER" ssh-keyscan -H "$HOST" >> "$KNOWN_HOSTS_FILE" 2>/dev/null || true
done
