#!/bin/bash

# Backup Realms Script
# This script exports Keycloak realm configurations for backup purposes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8082}"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin_strong_password_123}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

get_admin_token() {
    log "Getting admin access token..."
    
    local response=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$KEYCLOAK_ADMIN_USER" \
        -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
        -d "grant_type=password" \
        -d "client_id=admin-cli")
    
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to get admin token"
        return 1
    fi
    
    echo "$response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4
}

list_realms() {
    local admin_token="$1"
    
    log "Getting list of realms..."
    
    local response=$(curl -s "$KEYCLOAK_URL/admin/realms" \
        -H "Authorization: Bearer $admin_token")
    
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to get realms list"
        return 1
    fi
    
    echo "$response" | grep -o '"realm":"[^"]*"' | cut -d'"' -f4
}

export_realm() {
    local realm_name="$1"
    local admin_token="$2"
    local timestamp="$3"
    
    log "Exporting realm: $realm_name"
    
    local backup_file="$BACKUP_DIR/${realm_name}-realm-backup-${timestamp}.json"
    
    local response=$(curl -s -w "%{http_code}" "$KEYCLOAK_URL/admin/realms/$realm_name" \
        -H "Authorization: Bearer $admin_token" \
        -o "$backup_file")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log "✅ Successfully exported realm: $realm_name to $backup_file"
        
        # Pretty format the JSON
        if command -v jq >/dev/null 2>&1; then
            jq '.' "$backup_file" > "${backup_file}.tmp" && mv "${backup_file}.tmp" "$backup_file"
            log "📝 Formatted JSON for better readability"
        fi
        
        # Create a compressed backup
        gzip -c "$backup_file" > "${backup_file}.gz"
        log "🗜️  Created compressed backup: ${backup_file}.gz"
        
        return 0
    else
        log "❌ Failed to export realm: $realm_name (HTTP $http_code)"
        rm -f "$backup_file"
        return 1
    fi
}

export_users() {
    local realm_name="$1"
    local admin_token="$2"
    local timestamp="$3"
    
    log "Exporting users for realm: $realm_name"
    
    local users_file="$BACKUP_DIR/${realm_name}-users-backup-${timestamp}.json"
    
    local response=$(curl -s -w "%{http_code}" "$KEYCLOAK_URL/admin/realms/$realm_name/users" \
        -H "Authorization: Bearer $admin_token" \
        -o "$users_file")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log "✅ Successfully exported users for realm: $realm_name"
        
        # Pretty format the JSON
        if command -v jq >/dev/null 2>&1; then
            jq '.' "$users_file" > "${users_file}.tmp" && mv "${users_file}.tmp" "$users_file"
        fi
        
        # Count users
        local user_count
        if command -v jq >/dev/null 2>&1; then
            user_count=$(jq '. | length' "$users_file")
            log "👥 Exported $user_count users"
        fi
        
        return 0
    else
        log "❌ Failed to export users for realm: $realm_name (HTTP $http_code)"
        rm -f "$users_file"
        return 1
    fi
}

export_clients() {
    local realm_name="$1"
    local admin_token="$2"
    local timestamp="$3"
    
    log "Exporting clients for realm: $realm_name"
    
    local clients_file="$BACKUP_DIR/${realm_name}-clients-backup-${timestamp}.json"
    
    local response=$(curl -s -w "%{http_code}" "$KEYCLOAK_URL/admin/realms/$realm_name/clients" \
        -H "Authorization: Bearer $admin_token" \
        -o "$clients_file")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log "✅ Successfully exported clients for realm: $realm_name"
        
        # Pretty format the JSON
        if command -v jq >/dev/null 2>&1; then
            jq '.' "$clients_file" > "${clients_file}.tmp" && mv "${clients_file}.tmp" "$clients_file"
        fi
        
        return 0
    else
        log "❌ Failed to export clients for realm: $realm_name (HTTP $http_code)"
        rm -f "$clients_file"
        return 1
    fi
}

create_backup_manifest() {
    local timestamp="$1"
    local realm_list="$2"
    
    local manifest_file="$BACKUP_DIR/backup-manifest-${timestamp}.json"
    
    log "Creating backup manifest..."
    
    cat > "$manifest_file" << EOF
{
  "backup_timestamp": "$timestamp",
  "backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "keycloak_url": "$KEYCLOAK_URL",
  "backup_type": "full",
  "realms": [
$(echo "$realm_list" | sed 's/^/    "/' | sed 's/$/"/' | paste -sd ',' -)
  ],
  "files": [
$(find "$BACKUP_DIR" -name "*${timestamp}*" -type f | sed 's/^/    "/' | sed 's/$/"/' | paste -sd ',' -)
  ],
  "tools": {
    "script_version": "1.0.0",
    "jq_available": $(command -v jq >/dev/null 2>&1 && echo "true" || echo "false")
  }
}
EOF
    
    log "📋 Created backup manifest: $manifest_file"
}

cleanup_old_backups() {
    local days_to_keep="${1:-30}"
    
    log "Cleaning up backups older than $days_to_keep days..."
    
    local deleted_count=0
    
    find "$BACKUP_DIR" -name "*.json" -type f -mtime +$days_to_keep | while read -r file; do
        log "🗑️  Deleting old backup: $(basename "$file")"
        rm -f "$file"
        deleted_count=$((deleted_count + 1))
    done
    
    find "$BACKUP_DIR" -name "*.gz" -type f -mtime +$days_to_keep | while read -r file; do
        log "🗑️  Deleting old compressed backup: $(basename "$file")"
        rm -f "$file"
    done
    
    if [ $deleted_count -gt 0 ]; then
        log "🧹 Cleaned up $deleted_count old backup files"
    else
        log "🧹 No old backups to clean up"
    fi
}

main() {
    local backup_type="${1:-full}"
    local cleanup_days="${2:-30}"
    
    log "🚀 Starting Keycloak backup process (type: $backup_type)"
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    # Get admin token
    local admin_token
    admin_token=$(get_admin_token)
    
    if [ -z "$admin_token" ]; then
        log "ERROR: Failed to obtain admin token"
        exit 1
    fi
    
    # Get list of realms
    local realm_list
    realm_list=$(list_realms "$admin_token")
    
    if [ -z "$realm_list" ]; then
        log "ERROR: No realms found or failed to get realm list"
        exit 1
    fi
    
    log "Found realms: $(echo "$realm_list" | tr '\n' ' ')"
    
    local success_count=0
    local total_count=0
    
    # Export each realm
    for realm in $realm_list; do
        total_count=$((total_count + 1))
        
        log "Processing realm: $realm"
        
        if export_realm "$realm" "$admin_token" "$timestamp"; then
            success_count=$((success_count + 1))
            
            # Export additional data if requested
            if [ "$backup_type" = "full" ]; then
                export_users "$realm" "$admin_token" "$timestamp"
                export_clients "$realm" "$admin_token" "$timestamp"
            fi
        fi
    done
    
    # Create backup manifest
    create_backup_manifest "$timestamp" "$realm_list"
    
    # Cleanup old backups
    cleanup_old_backups "$cleanup_days"
    
    log "📊 Backup summary:"
    log "  - Total realms: $total_count"
    log "  - Successful backups: $success_count"
    log "  - Failed backups: $((total_count - success_count))"
    log "  - Backup location: $BACKUP_DIR"
    log "  - Backup timestamp: $timestamp"
    
    if [ $success_count -eq $total_count ]; then
        log "🎉 All backups completed successfully!"
        exit 0
    else
        log "⚠️  Some backups failed. Check the logs above."
        exit 1
    fi
}

# Handle script arguments
case "${1:-full}" in
    "full")
        main "full" "${2:-30}"
        ;;
    "realms-only")
        main "realms-only" "${2:-30}"
        ;;
    "cleanup")
        cleanup_old_backups "${2:-30}"
        ;;
    *)
        echo "Usage: $0 [full|realms-only|cleanup] [days_to_keep]"
        echo "  full        - Full backup including users and clients (default)"
        echo "  realms-only - Backup only realm configurations"
        echo "  cleanup     - Clean up old backups"
        echo "  days_to_keep - Number of days to keep backups (default: 30)"
        exit 1
        ;;
esac