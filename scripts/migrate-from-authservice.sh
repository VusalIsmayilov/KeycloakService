#!/bin/bash

# Migration Script from AuthService embedded Keycloak to Centralized Keycloak Service
# This script handles the complete migration process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AUTHSERVICE_DIR="$(dirname "$PROJECT_DIR")/AuthService"
API_GATEWAY_DIR="$(dirname "$PROJECT_DIR")/api-gateway"

# Configuration
OLD_KEYCLOAK_URL="${OLD_KEYCLOAK_URL:-http://localhost:8081}"
NEW_KEYCLOAK_URL="${NEW_KEYCLOAK_URL:-http://localhost:8082}"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin_strong_password_123}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

backup_current_configuration() {
    log "📦 Backing up current configuration..."
    
    local backup_dir="$PROJECT_DIR/migration-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup AuthService configuration
    if [ -f "$AUTHSERVICE_DIR/appsettings.json" ]; then
        cp "$AUTHSERVICE_DIR/appsettings.json" "$backup_dir/authservice-appsettings.json.backup"
        log "✅ Backed up AuthService appsettings.json"
    fi
    
    # Backup AuthService Program.cs
    if [ -f "$AUTHSERVICE_DIR/Program.cs" ]; then
        cp "$AUTHSERVICE_DIR/Program.cs" "$backup_dir/authservice-program.cs.backup"
        log "✅ Backed up AuthService Program.cs"
    fi
    
    # Backup API Gateway configuration
    if [ -f "$API_GATEWAY_DIR/nginx/conf.d/keycloak.conf" ]; then
        cp "$API_GATEWAY_DIR/nginx/conf.d/keycloak.conf" "$backup_dir/nginx-keycloak.conf.backup"
        log "✅ Backed up API Gateway Keycloak configuration"
    fi
    
    # Backup existing realm export
    if [ -f "$AUTHSERVICE_DIR/keycloak/realm-export.json" ]; then
        cp "$AUTHSERVICE_DIR/keycloak/realm-export.json" "$backup_dir/original-realm-export.json"
        log "✅ Backed up original realm export"
    fi
    
    log "📁 Backup created at: $backup_dir"
    echo "$backup_dir" > "$PROJECT_DIR/.migration-backup-path"
}

export_current_realm_data() {
    log "📤 Exporting current realm data from embedded Keycloak..."
    
    # Check if old Keycloak is running
    if ! curl -f -s "$OLD_KEYCLOAK_URL/health/ready" > /dev/null 2>&1; then
        log "⚠️  Old Keycloak instance not accessible. Using existing realm export if available."
        return 0
    fi
    
    # Try to export current realm data
    local admin_token
    admin_token=$(curl -s -X POST "$OLD_KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$KEYCLOAK_ADMIN_USER" \
        -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$admin_token" ]; then
        local export_file="$PROJECT_DIR/migration-export-$(date +%Y%m%d_%H%M%S).json"
        
        if curl -s "$OLD_KEYCLOAK_URL/admin/realms/authservice" \
            -H "Authorization: Bearer $admin_token" \
            -o "$export_file"; then
            log "✅ Exported current realm data to: $export_file"
        else
            log "⚠️  Failed to export current realm data"
        fi
    else
        log "⚠️  Could not authenticate with old Keycloak instance"
    fi
}

stop_old_keycloak() {
    log "🛑 Stopping old Keycloak instances..."
    
    # Stop AuthService containers (which may include Keycloak)
    if [ -f "$AUTHSERVICE_DIR/docker-compose.yml" ]; then
        (cd "$AUTHSERVICE_DIR" && docker-compose down keycloak 2>/dev/null || true)
        log "✅ Stopped AuthService Keycloak container"
    fi
    
    # Stop API Gateway if it has Keycloak
    if [ -f "$API_GATEWAY_DIR/docker-compose.yml" ]; then
        (cd "$API_GATEWAY_DIR" && docker-compose down keycloak 2>/dev/null || true)
        log "✅ Stopped API Gateway Keycloak container"
    fi
}

start_centralized_keycloak() {
    log "🚀 Starting centralized Keycloak service..."
    
    # Start the new Keycloak service
    (cd "$PROJECT_DIR" && docker-compose up -d)
    
    # Wait for it to be ready
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$NEW_KEYCLOAK_URL/health/ready" > /dev/null 2>&1; then
            log "✅ Centralized Keycloak is ready!"
            break
        fi
        
        log "Attempt $attempt/$max_attempts - Waiting for Keycloak to be ready..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log "❌ Centralized Keycloak failed to start"
        return 1
    fi
}

import_realm_data() {
    log "📥 Importing realm data to centralized Keycloak..."
    
    # Run the realm setup script
    if [ -x "$SCRIPT_DIR/setup-realms.sh" ]; then
        KEYCLOAK_URL="$NEW_KEYCLOAK_URL" "$SCRIPT_DIR/setup-realms.sh" setup
        log "✅ Realm data imported successfully"
    else
        log "❌ Setup script not found or not executable"
        return 1
    fi
}

update_authservice_configuration() {
    log "🔧 Updating AuthService configuration..."
    
    # Update appsettings.json
    if [ -f "$AUTHSERVICE_DIR/appsettings.json" ]; then
        # Create a temporary file with updated configuration
        local temp_file=$(mktemp)
        
        # Use jq to update the Keycloak configuration if available
        if command -v jq >/dev/null 2>&1; then
            jq --arg new_url "$NEW_KEYCLOAK_URL" \
               '.Keycloak.Authority = ($new_url + "/realms/authservice")' \
               "$AUTHSERVICE_DIR/appsettings.json" > "$temp_file"
            
            mv "$temp_file" "$AUTHSERVICE_DIR/appsettings.json"
            log "✅ Updated AuthService appsettings.json with new Keycloak URL"
        else
            # Fallback to sed if jq is not available
            sed -i.bak "s|\"Authority\": \".*\"|\"Authority\": \"$NEW_KEYCLOAK_URL/realms/authservice\"|g" \
                "$AUTHSERVICE_DIR/appsettings.json"
            log "✅ Updated AuthService appsettings.json (sed fallback)"
        fi
    fi
    
    # Update Program.cs to remove embedded Keycloak configuration if needed
    log "ℹ️  AuthService Program.cs may need manual review for Keycloak authentication configuration"
}

update_api_gateway_configuration() {
    log "🔧 Updating API Gateway configuration..."
    
    # Update Keycloak proxy configuration
    if [ -f "$API_GATEWAY_DIR/nginx/conf.d/keycloak.conf" ]; then
        # Update upstream configuration
        sed -i.bak "s|server .*:8080|server keycloak:8080|g" \
            "$API_GATEWAY_DIR/nginx/conf.d/keycloak.conf"
        
        log "✅ Updated API Gateway Keycloak configuration"
    fi
    
    # Add Keycloak service to API Gateway docker-compose if not present
    if [ -f "$API_GATEWAY_DIR/docker-compose.yml" ]; then
        if ! grep -q "keycloak_network" "$API_GATEWAY_DIR/docker-compose.yml"; then
            log "ℹ️  API Gateway docker-compose.yml may need manual update to connect to keycloak_network"
        fi
    fi
}

update_projectservice_configuration() {
    local projectservice_dir="$(dirname "$PROJECT_DIR")/ProjectService"
    
    if [ -d "$projectservice_dir" ]; then
        log "🔧 Updating ProjectService configuration..."
        
        # Update ProjectService Keycloak configuration
        if [ -f "$projectservice_dir/appsettings.json" ]; then
            if command -v jq >/dev/null 2>&1; then
                local temp_file=$(mktemp)
                jq --arg new_url "$NEW_KEYCLOAK_URL" \
                   '.Keycloak.Authority = ($new_url + "/realms/authservice")' \
                   "$projectservice_dir/appsettings.json" > "$temp_file"
                
                mv "$temp_file" "$projectservice_dir/appsettings.json"
                log "✅ Updated ProjectService appsettings.json"
            fi
        fi
    fi
}

test_migration() {
    log "🧪 Testing migration..."
    
    # Test Keycloak accessibility
    if curl -f -s "$NEW_KEYCLOAK_URL/realms/authservice/.well-known/openid_configuration" > /dev/null; then
        log "✅ Keycloak OIDC endpoint accessible"
    else
        log "❌ Keycloak OIDC endpoint not accessible"
        return 1
    fi
    
    # Test admin console
    if curl -f -s "$NEW_KEYCLOAK_URL/admin" > /dev/null; then
        log "✅ Keycloak admin console accessible"
    else
        log "❌ Keycloak admin console not accessible"
        return 1
    fi
    
    log "🎉 Migration test completed successfully!"
}

rollback_migration() {
    log "🔄 Rolling back migration..."
    
    local backup_path
    if [ -f "$PROJECT_DIR/.migration-backup-path" ]; then
        backup_path=$(cat "$PROJECT_DIR/.migration-backup-path")
        
        if [ -d "$backup_path" ]; then
            # Restore configurations
            if [ -f "$backup_path/authservice-appsettings.json.backup" ]; then
                cp "$backup_path/authservice-appsettings.json.backup" "$AUTHSERVICE_DIR/appsettings.json"
                log "✅ Restored AuthService appsettings.json"
            fi
            
            if [ -f "$backup_path/authservice-program.cs.backup" ]; then
                cp "$backup_path/authservice-program.cs.backup" "$AUTHSERVICE_DIR/Program.cs"
                log "✅ Restored AuthService Program.cs"
            fi
            
            if [ -f "$backup_path/nginx-keycloak.conf.backup" ]; then
                cp "$backup_path/nginx-keycloak.conf.backup" "$API_GATEWAY_DIR/nginx/conf.d/keycloak.conf"
                log "✅ Restored API Gateway Keycloak configuration"
            fi
        fi
    fi
    
    # Stop centralized Keycloak
    (cd "$PROJECT_DIR" && docker-compose down)
    
    log "✅ Rollback completed"
}

main() {
    local action="${1:-migrate}"
    
    case "$action" in
        "migrate")
            log "🚀 Starting Keycloak migration to centralized service"
            
            backup_current_configuration
            export_current_realm_data
            stop_old_keycloak
            start_centralized_keycloak
            import_realm_data
            update_authservice_configuration
            update_api_gateway_configuration
            update_projectservice_configuration
            test_migration
            
            log "🎉 Migration completed successfully!"
            log "📋 Next steps:"
            log "   1. Test all services with new Keycloak configuration"
            log "   2. Update any hardcoded Keycloak URLs in applications"
            log "   3. Remove old Keycloak containers if everything works"
            log "   4. Update CI/CD pipelines if applicable"
            ;;
        "rollback")
            rollback_migration
            ;;
        "test")
            test_migration
            ;;
        *)
            echo "Usage: $0 [migrate|rollback|test]"
            echo "  migrate  - Perform full migration (default)"
            echo "  rollback - Rollback to previous configuration"
            echo "  test     - Test current migration status"
            exit 1
            ;;
    esac
}

# Handle script execution
main "$@"