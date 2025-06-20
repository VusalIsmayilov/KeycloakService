# Keycloak Custom Providers

This directory contains custom Keycloak providers for extending functionality.

## Provider Types

### Authentication Providers
- Custom authentication flows
- Two-factor authentication
- Biometric authentication
- SMS/Email OTP providers

### User Storage Providers
- LDAP/Active Directory integration
- Custom database connections
- Legacy system integration
- External user stores

### Identity Providers
- Custom OAuth2 providers
- SAML identity providers
- Custom social login providers
- Enterprise SSO integration

### Event Listeners
- Audit logging
- User activity tracking
- Security monitoring
- Integration webhooks

### Protocol Mappers
- Custom claim mappings
- Token enrichment
- Attribute transformation
- Role mapping

## Development

### Setup Development Environment
1. Install Maven or Gradle
2. Set up Keycloak development dependencies
3. Create provider project structure
4. Implement required interfaces

### Example Provider Structure
```
custom-auth-provider/
├── src/
│   └── main/
│       ├── java/
│       │   └── com/authservice/keycloak/
│       │       ├── CustomAuthenticator.java
│       │       └── CustomAuthenticatorFactory.java
│       └── resources/
│           └── META-INF/
│               └── services/
│                   └── org.keycloak.authentication.AuthenticatorFactory
├── pom.xml
└── README.md
```

### Building Providers
```bash
mvn clean package
```

### Deployment
1. Copy JAR to `/opt/keycloak/providers/`
2. Restart Keycloak
3. Configure in admin console

## Available Custom Providers

### SMS OTP Provider
- SMS-based two-factor authentication
- Multiple SMS gateway support
- Rate limiting and retry logic
- Configurable message templates

### Audit Event Listener
- Comprehensive audit logging
- Database persistence
- Real-time monitoring
- Compliance reporting

### Custom User Federation
- Legacy database integration
- User migration utilities
- Attribute synchronization
- Group membership mapping

## Configuration

### Provider Configuration
```json
{
  "providerId": "custom-sms-otp",
  "config": {
    "sms.gateway.url": "https://api.sms-gateway.com/send",
    "sms.gateway.token": "your-api-token",
    "sms.template": "Your verification code is: {code}",
    "sms.code.length": "6",
    "sms.code.ttl": "300"
  }
}
```

### Environment Variables
```bash
CUSTOM_SMS_GATEWAY_URL=https://api.sms-gateway.com/send
CUSTOM_SMS_GATEWAY_TOKEN=your-api-token
CUSTOM_AUDIT_DB_URL=jdbc:postgresql://audit-db:5432/audit
```

## Testing

### Unit Testing
```bash
mvn test
```

### Integration Testing
1. Deploy to test Keycloak instance
2. Configure test realm
3. Run authentication flows
4. Verify provider behavior

## Security Considerations

1. **Input Validation**: Validate all user inputs
2. **Rate Limiting**: Implement rate limiting for security
3. **Encryption**: Encrypt sensitive data
4. **Logging**: Avoid logging sensitive information
5. **Dependencies**: Keep dependencies updated

## Monitoring

### Metrics
- Authentication success/failure rates
- Provider response times
- Error rates and types
- User behavior patterns

### Alerts
- Provider failures
- Security violations
- Performance degradation
- Configuration changes

## Documentation

### Provider Documentation
- Installation instructions
- Configuration parameters
- API reference
- Troubleshooting guide

### User Documentation
- End-user guides
- Administrative procedures
- Security best practices
- FAQ and support