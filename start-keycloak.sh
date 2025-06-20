#!/bin/bash

# Start Keycloak Service Script
# This script starts the centralized Keycloak service

set -e

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "🚀 Starting Centralized Keycloak Service"

# Navigate to KeycloakService directory
cd "$(dirname "$0")"

# Check if microservices network exists
if ! docker network ls | grep -q microservices_network; then
    log "📡 Creating microservices_network"
    docker network create microservices_network --driver bridge --subnet 172.20.0.0/16
else
    log "📡 microservices_network already exists"
fi

# Start the Keycloak service
log "🔧 Starting Keycloak containers..."
docker-compose up -d

# Wait a moment for containers to start
sleep 5

# Check container status
log "📊 Container Status:"
docker-compose ps

# Check if Keycloak is accessible
log "🔍 Checking Keycloak accessibility..."
for i in {1..12}; do
    if curl -f -s http://localhost:8082/health/ready > /dev/null 2>&1; then
        log "✅ Keycloak is ready!"
        break
    elif [ $i -eq 12 ]; then
        log "❌ Keycloak failed to become ready after 60 seconds"
        docker-compose logs keycloak
        exit 1
    else
        log "⏳ Waiting for Keycloak to be ready... (attempt $i/12)"
        sleep 5
    fi
done

# Show important URLs
log "🌐 Keycloak Service URLs:"
log "   Admin Console: http://localhost:8082/admin"
log "   Admin User: admin"
log "   Admin Password: admin_strong_password_123"
log "   Health Check: http://localhost:8082/health/ready"
log "   Metrics: http://localhost:8082/metrics"

# Show next steps
log "📋 Next Steps:"
log "   1. Run setup script: ./scripts/setup-realms.sh"
log "   2. Import realms: ./scripts/setup-realms.sh setup"
log "   3. Test migration: ./scripts/migrate-from-authservice.sh test"

log "🎉 Keycloak service started successfully!"