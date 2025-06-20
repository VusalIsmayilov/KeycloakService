# Keycloak Custom Themes

This directory contains custom themes for the Keycloak service.

## Theme Structure

```
themes/
├── authservice/
│   ├── login/
│   │   ├── theme.properties
│   │   ├── login.ftl
│   │   ├── register.ftl
│   │   └── resources/
│   │       ├── css/
│   │       ├── img/
│   │       └── js/
│   ├── account/
│   │   ├── theme.properties
│   │   └── resources/
│   ├── admin/
│   │   ├── theme.properties
│   │   └── resources/
│   └── email/
│       ├── theme.properties
│       ├── html/
│       └── text/
└── README.md
```

## Available Themes

### AuthService Theme
- **Login Theme**: Custom branding for login pages
- **Account Theme**: User account management pages
- **Admin Theme**: Administrative console styling
- **Email Theme**: Email templates for notifications

## Theme Development

1. Create theme directory: `themes/your-theme-name/`
2. Add theme.properties file
3. Override template files (.ftl)
4. Add custom CSS, JavaScript, and images
5. Restart Keycloak or use development mode for live reload

## Theme Properties

Example `theme.properties`:
```properties
parent=keycloak
import=common/keycloak

styles=css/login.css css/custom.css
scripts=js/custom.js

locales=en,es,fr,de
```

## Custom CSS

Add custom styling in `resources/css/` directory:
- `login.css` - Login page styles
- `admin.css` - Admin console styles
- `account.css` - Account management styles

## Email Templates

Customize email templates in `email/html/` and `email/text/`:
- `email-verification.ftl` - Email verification
- `password-reset.ftl` - Password reset
- `identity-provider-link.ftl` - Social login linking

## Internationalization

Add translations in `messages/` directory:
- `messages_en.properties`
- `messages_es.properties`
- `messages_fr.properties`

## Testing Themes

1. Set theme in realm configuration
2. Use browser developer tools for debugging
3. Test with different locales
4. Verify email templates with test sends

## Production Considerations

1. Optimize CSS and JavaScript files
2. Compress images
3. Test across different browsers
4. Validate accessibility compliance
5. Performance testing with realistic load