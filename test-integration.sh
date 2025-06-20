#!/bin/bash

# Comprehensive Keycloak Integration Test Script
# This script tests the centralized Keycloak service and its integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYCLOAK_URL="http://localhost:8082"
API_GATEWAY_URL="http://localhost:8081"
AUTHSERVICE_URL="https://localhost:443"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

success() {
    echo "✅ $1"
}

error() {
    echo "❌ $1"
}

warning() {
    echo "⚠️  $1"
}

test_keycloak_direct() {
    log "Testing direct Keycloak access..."
    
    # Test health endpoint
    if curl -f -s "$KEYCLOAK_URL/health/ready" > /dev/null; then
        success "Keycloak health endpoint accessible"
    else
        error "Keycloak health endpoint not accessible"
        return 1
    fi
    
    # Test admin console
    local admin_response=$(curl -s -w "%{http_code}" "$KEYCLOAK_URL/admin" -o /dev/null)
    if [ "$admin_response" = "200" ] || [ "$admin_response" = "302" ]; then
        success "Keycloak admin console accessible"
    else
        error "Keycloak admin console not accessible (HTTP $admin_response)"
    fi
    
    # Test realm configuration
    if curl -f -s "$KEYCLOAK_URL/realms/authservice/.well-known/openid_configuration" > /dev/null; then
        success "AuthService realm configuration accessible"
        
        # Get and display key endpoints
        local config=$(curl -s "$KEYCLOAK_URL/realms/authservice/.well-known/openid_configuration")
        echo "📋 Key endpoints:"
        echo "$config" | grep -o '"[^"]*_endpoint":"[^"]*"' | sed 's/"//g' | sed 's/:/: /' | head -5
    else
        error "AuthService realm configuration not accessible"
        return 1
    fi
}

test_api_gateway_proxy() {
    log "Testing API Gateway proxy to Keycloak..."
    
    # Test realm configuration through API Gateway
    if curl -f -s "$API_GATEWAY_URL/realms/authservice/.well-known/openid_configuration" > /dev/null; then
        success "Keycloak accessible through API Gateway"
    else
        error "Keycloak not accessible through API Gateway"
        warning "Check if API Gateway is running and connected to keycloak_network"
    fi
    
    # Test admin console through API Gateway
    local admin_response=$(curl -s -w "%{http_code}" "$API_GATEWAY_URL/admin" -o /dev/null)
    if [ "$admin_response" = "200" ] || [ "$admin_response" = "302" ]; then
        success "Keycloak admin console accessible through API Gateway"
    else
        warning "Keycloak admin console not accessible through API Gateway (HTTP $admin_response)"
    fi
}

test_authservice_integration() {
    log "Testing AuthService integration with centralized Keycloak..."
    
    # Test AuthService health
    if curl -k -f -s "$AUTHSERVICE_URL/health" > /dev/null; then
        success "AuthService is running"
        
        # Test JWKS endpoint
        if curl -k -f -s "$AUTHSERVICE_URL/.well-known/jwks.json" > /dev/null; then
            success "AuthService JWKS endpoint accessible"
        else
            warning "AuthService JWKS endpoint not accessible"
        fi
        
        # Test OpenID configuration
        if curl -k -f -s "$AUTHSERVICE_URL/.well-known/openid_configuration" > /dev/null; then
            success "AuthService OpenID configuration accessible"
        else
            warning "AuthService OpenID configuration not accessible"
        fi
        
    else
        warning "AuthService not running or not accessible"
    fi
}

test_container_status() {
    log "Checking container status..."
    
    # Check Keycloak containers
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q keycloak; then
        success "Keycloak containers are running:"
        docker ps --format "table {{.Names}}\t{{.Status}}" | grep keycloak
    else
        error "Keycloak containers not found"
        return 1
    fi
    
    # Check networks
    if docker network ls | grep -q keycloak_network; then
        success "keycloak_network exists"
    else
        error "keycloak_network not found"
    fi
    
    if docker network ls | grep -q microservices_network; then
        success "microservices_network exists"
    else
        warning "microservices_network not found"
    fi
}

test_database_connection() {
    log "Testing database connection..."
    
    # Check if database container is running
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q keycloak_postgres; then
        success "Keycloak database container running"
        
        # Test database connection
        if docker exec keycloak_postgres pg_isready -U keycloak_user -d keycloak_db > /dev/null 2>&1; then
            success "Database connection healthy"
        else
            error "Database connection failed"
        fi
    else
        error "Keycloak database container not found"
    fi
}

generate_test_token() {
    log "Testing token generation..."
    
    # Try to get an access token using client credentials
    local token_response=$(curl -s -X POST "$KEYCLOAK_URL/realms/authservice/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials" \
        -d "client_id=authservice-client" \
        -d "client_secret=authservice-client-secret-strong-key-123")
    
    if echo "$token_response" | grep -q "access_token"; then
        success "Token generation successful"
        local token=$(echo "$token_response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
        echo "🔑 Token length: ${#token} characters"
    else
        warning "Token generation failed"
        echo "Response: $token_response"
    fi
}

cleanup_test() {
    log "Cleaning up test resources..."
    # Add any cleanup logic here if needed
}

main() {
    log "🚀 Starting Keycloak Integration Tests"
    
    local failed_tests=0
    
    # Run tests
    if ! test_container_status; then
        ((failed_tests++))
    fi
    
    if ! test_database_connection; then
        ((failed_tests++))
    fi
    
    if ! test_keycloak_direct; then
        ((failed_tests++))
    fi
    
    test_api_gateway_proxy
    test_authservice_integration
    generate_test_token
    
    # Summary
    log "📊 Test Summary:"
    if [ $failed_tests -eq 0 ]; then
        success "All critical tests passed!"
        log "🌐 Access URLs:"
        log "   Keycloak Admin: $KEYCLOAK_URL/admin"
        log "   Keycloak via Gateway: $API_GATEWAY_URL/admin"
        log "   AuthService Realm: $KEYCLOAK_URL/realms/authservice"
        log "   OIDC Config: $KEYCLOAK_URL/realms/authservice/.well-known/openid_configuration"
    else
        error "$failed_tests critical tests failed"
        log "🔧 Troubleshooting steps:"
        log "   1. Check if containers are running: docker-compose ps"
        log "   2. Check container logs: docker-compose logs keycloak"
        log "   3. Verify network connectivity: docker network ls"
        log "   4. Restart services if needed: docker-compose restart"
    fi
    
    cleanup_test
}

# Handle script arguments
case "${1:-test}" in
    "test")
        main
        ;;
    "containers")
        test_container_status
        ;;
    "direct")
        test_keycloak_direct
        ;;
    "gateway")
        test_api_gateway_proxy
        ;;
    "auth")
        test_authservice_integration
        ;;
    "token")
        generate_test_token
        ;;
    *)
        echo "Usage: $0 [test|containers|direct|gateway|auth|token]"
        echo "  test       - Run all tests (default)"
        echo "  containers - Test container status only"
        echo "  direct     - Test direct Keycloak access"
        echo "  gateway    - Test API Gateway proxy"
        echo "  auth       - Test AuthService integration"
        echo "  token      - Test token generation"
        exit 1
        ;;
esac