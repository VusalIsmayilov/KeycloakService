#!/bin/bash

# Setup Realms Script
# This script sets up Keycloak realms for the first time

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8082}"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin_strong_password_123}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

wait_for_keycloak() {
    log "Waiting for Keycloak to be ready..."
    
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$KEYCLOAK_URL/health/ready" > /dev/null 2>&1; then
            log "Keycloak is ready!"
            return 0
        fi
        
        log "Attempt $attempt/$max_attempts - Keycloak not ready yet, waiting 5 seconds..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    log "ERROR: Keycloak failed to become ready after $max_attempts attempts"
    return 1
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

import_realm() {
    local realm_file="$1"
    local realm_name="$2"
    local admin_token="$3"
    
    log "Importing realm: $realm_name from $realm_file"
    
    if [ ! -f "$realm_file" ]; then
        log "ERROR: Realm file not found: $realm_file"
        return 1
    fi
    
    local response=$(curl -s -w "%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms" \
        -H "Authorization: Bearer $admin_token" \
        -H "Content-Type: application/json" \
        -d @"$realm_file")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "201" ]; then
        log "✅ Successfully imported realm: $realm_name"
        return 0
    elif [ "$http_code" = "409" ]; then
        log "⚠️  Realm already exists: $realm_name"
        return 0
    else
        log "❌ Failed to import realm: $realm_name (HTTP $http_code)"
        log "Response: ${response%???}"
        return 1
    fi
}

update_realm() {
    local realm_file="$1"
    local realm_name="$2"
    local admin_token="$3"
    
    log "Updating realm: $realm_name"
    
    local response=$(curl -s -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/$realm_name" \
        -H "Authorization: Bearer $admin_token" \
        -H "Content-Type: application/json" \
        -d @"$realm_file")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "204" ]; then
        log "✅ Successfully updated realm: $realm_name"
        return 0
    else
        log "❌ Failed to update realm: $realm_name (HTTP $http_code)"
        return 1
    fi
}

verify_realm() {
    local realm_name="$1"
    local admin_token="$2"
    
    local response=$(curl -s -w "%{http_code}" "$KEYCLOAK_URL/admin/realms/$realm_name" \
        -H "Authorization: Bearer $admin_token")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" = "200" ]; then
        log "✅ Realm verified: $realm_name"
        return 0
    else
        log "❌ Realm verification failed: $realm_name"
        return 1
    fi
}

main() {
    log "🚀 Starting Keycloak realm setup process"
    
    # Wait for Keycloak to be ready
    if ! wait_for_keycloak; then
        exit 1
    fi
    
    # Get admin token
    local admin_token
    admin_token=$(get_admin_token)
    
    if [ -z "$admin_token" ]; then
        log "ERROR: Failed to obtain admin token"
        exit 1
    fi
    
    log "Successfully obtained admin token"
    
    # Import/Update AuthService realm
    local authservice_realm="$PROJECT_DIR/keycloak/realm-configs/authservice-realm.json"
    
    if import_realm "$authservice_realm" "authservice" "$admin_token"; then
        verify_realm "authservice" "$admin_token"
    else
        log "Attempting to update existing realm..."
        update_realm "$authservice_realm" "authservice" "$admin_token"
        verify_realm "authservice" "$admin_token"
    fi
    
    # Configure realm settings
    log "Configuring realm settings..."
    
    # Set up SMTP configuration (optional)
    # curl -s -X PUT "$KEYCLOAK_URL/admin/realms/authservice" \
    #     -H "Authorization: Bearer $admin_token" \
    #     -H "Content-Type: application/json" \
    #     -d '{"smtpServer": {"host": "smtp.gmail.com", "port": "587", "auth": "true", "ssl": "false", "starttls": "true"}}'
    
    log "📊 Realm setup summary:"
    log "  - AuthService realm: ✅ Ready"
    log "  - Admin console: $KEYCLOAK_URL/admin"
    log "  - AuthService realm: $KEYCLOAK_URL/realms/authservice"
    log "  - OIDC endpoint: $KEYCLOAK_URL/realms/authservice/.well-known/openid_configuration"
    
    log "🎉 Keycloak realm setup completed successfully!"
    
    # Test the setup
    log "Testing realm configuration..."
    
    local oidc_response=$(curl -s "$KEYCLOAK_URL/realms/authservice/.well-known/openid_configuration")
    if echo "$oidc_response" | grep -q "authorization_endpoint"; then
        log "✅ OIDC configuration endpoint working"
    else
        log "❌ OIDC configuration endpoint not working"
    fi
}

# Handle script arguments
case "${1:-setup}" in
    "setup")
        main
        ;;
    "test")
        wait_for_keycloak && log "Keycloak is ready for testing"
        ;;
    "token")
        get_admin_token
        ;;
    *)
        echo "Usage: $0 [setup|test|token]"
        echo "  setup - Run full realm setup (default)"
        echo "  test  - Test Keycloak availability"
        echo "  token - Get admin token"
        exit 1
        ;;
esac