
[README.md](https://github.com/user-attachments/files/21565696/README.md)
# Licenstra™ - Professional Digital License Management

[![GitHub Marketplace](https://img.shields.io/badge/GitHub-Marketplace-blue?logo=github)](https://github.com/marketplace/actions/licenstra-license-generator)
[![Replit](https://img.shields.io/badge/Run%20on-Replit-blue?logo=replit)](https://replit.com/@[your-username]/licenstra)

🚀 **Generate professional digital licenses with automated multi-language support and subscription management**

## ✨ Features

- 🌍 **Multi-language Support**: Automatic language detection (English, Swedish, German, Spanish, French)
- 📄 **Professional PDFs**: Legally compliant certificates with professional formatting
- 💳 **Subscription Management**: Basic ($19.99), Professional ($59.99), Enterprise ($149.99) monthly plans
- ⚡ **Instant Delivery**: Automated email delivery of licenses
- 🔒 **Secure Verification**: UUID-based license verification system
- 📊 **Quota Management**: Automatic monthly quota tracking and enforcement

## 🚀 Quick Start

### GitHub Action Usage

Add this to your workflow (`.github/workflows/license.yml`):

```yaml
name: Generate License
on:
  workflow_dispatch:
    inputs:
      license_title:
        description: 'License Title'
        required: true
      license_description:
        description: 'License Description'
        required: true
      licensee_email:
        description: 'Licensee Email'
        required: true

jobs:
  generate-license:
    runs-on: ubuntu-latest
    steps:
      - name: Generate Digital License
        uses: [your-username]/licenstra@v1
        with:
          license_title: ${{ github.event.inputs.license_title }}
          license_description: ${{ github.event.inputs.license_description }}
          licensee_email: ${{ github.event.inputs.licensee_email }}
          license_type: 'Commercial'
```

### Replit Deployment

[![Run on Replit](https://replit.com/badge/github/[your-username]/licenstra)](https://replit.com/@[your-username]/licenstra)

1. Click "Run on Replit" 
2. Add your Stripe API keys to Secrets
3. Configure email settings
4. Your license management system is live!

## 💰 Pricing Plans

| Plan | Price | Licenses/Month | Features |
|------|-------|----------------|----------|
| **Basic** | $19.99 | 10 | Multi-language PDFs, Email delivery |
| **Professional** | $59.99 | 50 | Custom branding, Analytics, API access |
| **Enterprise** | $149.99 | Unlimited | White-label, Custom integrations |

## 📋 How It Works

1. **Fill License Details**: Enter license information in the web interface
2. **Choose Plan**: Select monthly subscription tier
3. **Automated Processing**: Pay once, create licenses anytime until quota reached
4. **Instant Delivery**: Receive professional PDF via email
5. **Return Anytime**: Create more licenses until monthly quota resets

## 🛠️ Technical Stack

- **Backend**: Flask with PostgreSQL
- **PDF Generation**: FPDF with multi-language support
- **Payments**: Stripe integration with webhook automation
- **Email**: SMTP delivery with professional templates
- **Deployment**: Replit-optimized with multiple entry points

## 🌍 Language Support

Automatic language detection based on email domains:
- 🇺🇸 English (default)
- 🇸🇪 Swedish (.se domains)
- 🇩🇪 German (.de domains)
- 🇪🇸 Spanish (.es domains)
- 🇫🇷 French (.fr domains)

## 🔧 Configuration

### Required Environment Variables

For full deployment, set these in your environment:

```bash
# Stripe Configuration
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Database
DATABASE_URL=postgresql://...

# Email (optional - for notifications)
SMTP_HOST=smtp.your-provider.com
SMTP_USER=your-email@domain.com
SMTP_PASS=your-password
```

### GitHub Action Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `license_title` | Title of the license | Yes | - |
| `license_description` | Detailed license terms | Yes | - |
| `licensee_email` | Recipient email address | Yes | - |
| `license_type` | Type of license | No | `Commercial` |
| `language` | License language | No | `auto` |

### GitHub Action Outputs

| Output | Description |
|--------|-------------|
| `license_id` | Unique license identifier |
| `pdf_url` | Path to generated PDF |
| `verification_url` | License verification URL |

## 🚀 Revenue Potential

Perfect for entrepreneurs and businesses:

- **10 Basic customers** = $199.90/month recurring revenue
- **10 Professional customers** = $599.90/month recurring revenue  
- **10 Enterprise customers** = $1,499.90/month recurring revenue

**Fully automated** - customers pay, create licenses, and return monthly. No manual intervention required!

## 📊 Success Metrics

- ✅ **Global Market Ready**: Multi-language, USD pricing
- ✅ **Subscription Model**: Predictable recurring revenue
- ✅ **Self-Service**: Complete automation, no support overhead
- ✅ **Scalable**: Unlimited concurrent users
- ✅ **Marketplace Ready**: Available on GitHub & Replit

## 🤝 Support & Community

- 📧 **Email**: support@licenstra.com
- 🌐 **Website**: https://licenstra.replit.app
- 📚 **Documentation**: Full setup guides included
- 🔍 **License Verification**: https://licenstra.replit.app/verify

## 📄 License

This project is proprietary software. See [LICENSE](LICENSE) for details.

## 🏷️ Keywords

`digital-licenses` `pdf-generation` `multi-language` `subscription-saas` `stripe-integration` `business-automation` `legal-documents` `revenue-generation` `github-action` `replit-app`

---

**Ready to start generating revenue with professional digital licensing?**

[![Deploy on Replit](https://replit.com/badge/github/[your-username]/licenstra)](https://replit.com/@[your-username]/licenstra) [![Use GitHub Action](https://img.shields.io/badge/Use-GitHub%20Action-blue?logo=github)](https://github.com/marketplace/actions/licenstra-license-generator)
