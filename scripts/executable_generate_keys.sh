#!/usr/bin/env bash

# File: update_known_hosts.sh
# Description: Extracts hosts from ~/.ssh/config and updates known_hosts

CONFIG_FILE="${HOME}/.ssh/config"
KNOWN_HOSTS="${HOME}/.ssh/known_hosts"
TMP_HOSTS=$(mktemp)
TMP_KEYS=$(mktemp)

# Extract hostnames and IPs from config
awk '
    $1 == "Host" {
        for (i = 2; i <= NF; i++) {
            if ($i !~ /^[*?]/) print $i
        }
    }
    $1 == "Hostname" {
        print $2
    }
' "$CONFIG_FILE" | sort -u > "$TMP_HOSTS"

# Validate entries (basic IP/domain check)
grep -E '^[a-zA-Z0-9.-]+$' "$TMP_HOSTS" > "${TMP_HOSTS}.valid"

# Scan keys
echo "Scanning SSH keys for hosts..."
ssh-keyscan -T 5 -f "${TMP_HOSTS}.valid" 2>/dev/null > "$TMP_KEYS"

# Backup known_hosts
cp "$KNOWN_HOSTS" "${KNOWN_HOSTS}.bak"

# Merge new keys, avoiding duplicates
cat "$TMP_KEYS" >> "$KNOWN_HOSTS"
sort -u "$KNOWN_HOSTS" -o "$KNOWN_HOSTS"

# Cleanup
rm -f "$TMP_HOSTS" "${TMP_HOSTS}.valid" "$TMP_KEYS"

echo "✔ known_hosts updated. Backup saved as ${KNOWN_HOSTS}.bak"
