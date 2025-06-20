# Keycloak Service

Centralized Identity and Access Management service for all microservices.

## Overview

This service provides centralized authentication and authorization for the entire microservices ecosystem using Keycloak.

## Directory Structure

```
KeycloakService/
├── docker-compose.yml              # Main Keycloak service configuration
├── keycloak/
│   ├── themes/                     # Custom Keycloak themes
│   ├── realm-configs/              # Realm configuration files
│   │   ├── master-realm.json       # Master realm configuration
│   │   └── authservice-realm.json  # AuthService realm configuration
│   └── custom-providers/           # Custom Keycloak providers
├── scripts/
│   ├── setup-realms.sh            # Initial realm setup script
│   ├── import-realms.sh            # Import realm configurations
│   ├── backup-realms.sh            # Backup realm data
│   └── migrate-from-authservice.sh # Migration script
├── config/
│   └── keycloak.conf               # Keycloak configuration
└── README.md                       # This file
```

## Features

- **Multi-Realm Support**: Separate realms for different services
- **Centralized User Management**: Single source of truth for users
- **SSO (Single Sign-On)**: Shared authentication across services
- **Role-Based Access Control**: Centralized permission management
- **Federation Ready**: Support for LDAP, Active Directory, Social logins
- **High Availability**: Multi-instance support with database clustering

## Realms

### Master Realm
- Administrative access to Keycloak
- Super admin users
- Cross-realm management

### AuthService Realm
- User authentication and registration
- JWT token issuance
- Password reset and email verification
- Role assignments (Admin, User1, User2)

### ProjectService Realm (Future)
- Project-specific authentication
- Contractor management
- Project permissions

## Client Applications

1. **AuthService**: Backend authentication service
2. **ProjectService**: Project management service
3. **Flutter App**: Mobile/web frontend application
4. **Admin Console**: Administrative interface

## Getting Started

1. Start the Keycloak service:
   ```bash
   docker-compose up -d
   ```

2. Access Keycloak Admin Console:
   ```
   http://localhost:8080/admin
   ```

3. Import realm configurations:
   ```bash
   ./scripts/setup-realms.sh
   ```

## Configuration

- **Database**: PostgreSQL dedicated for Keycloak
- **SSL/TLS**: Reverse proxy handled by API Gateway
- **Clustering**: Redis for session sharing (future)
- **Backup**: Automated realm exports

## Migration from AuthService

The `scripts/migrate-from-authservice.sh` script handles the migration from the embedded Keycloak setup in AuthService to this centralized service.

## Security

- Dedicated database with encrypted connections
- Secure admin credentials
- Rate limiting and DDoS protection via API Gateway
- Audit logging enabled
- Regular security updates

## Monitoring

- Health checks for service availability
- Metrics export for monitoring systems
- Log aggregation for troubleshooting
- Performance monitoring

## Development

For development, you can run Keycloak with:
```bash
docker-compose -f docker-compose.dev.yml up -d
```

## Production

Production deployment includes:
- Database clustering
- Load balancing
- SSL termination
- Monitoring and alerting
- Backup and disaster recovery