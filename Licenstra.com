name: 'Licenstra Digital License Generator'
description: 'Generate professional digital licenses with multi-language support and automated PDF delivery'
author: 'Licenstra'
branding:
  icon: 'file-text'
  color: 'blue'

inputs:
  license_title:
    description: 'Title of the license to generate'
    required: true
  license_description:
    description: 'Description of the license terms'
    required: true
  licensee_email:
    description: 'Email address of the license recipient'
    required: true
  license_type:
    description: 'Type of license (Commercial, Personal, Educational, etc.)'
    required: true
    default: 'Commercial'
  language:
    description: 'Language for the license (auto-detected from email if not specified)'
    required: false
    default: 'auto'

outputs:
  license_id:
    description: 'Generated unique license identifier'
  pdf_url:
    description: 'URL to the generated PDF license'
  verification_url:
    description: 'URL for license verification'

runs:
  using: 'docker'
  image: 'Dockerfile'
  env:
    LICENSE_TITLE: ${{ inputs.license_title }}
    LICENSE_DESCRIPTION: ${{ inputs.license_description }}
    LICENSEE_EMAIL: ${{ inputs.licensee_email }}
    LICENSE_TYPE: ${{ inputs.license_type }}
    LANGUAGE: ${{ inputs.language }}
FROM python:3.11-slim

LABEL "com.github.actions.name"="Licenstra License Generator"
LABEL "com.github.actions.description"="Generate professional digital licenses"
LABEL "com.github.actions.icon"="file-text"
LABEL "com.github.actions.color"="blue"

WORKDIR /action

# Install system dependencies
RUN apt-get update && apt-get install -y \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies directly
RUN pip install --no-cache-dir \
    flask==3.0.0 \
    flask-cors==4.0.0 \
    fpdf2==2.7.6 \
    pillow==10.1.0 \
    pyyaml==6.0.1 \
    requests==2.31.0

# Copy application files
COPY . .

# Create entrypoint script
RUN echo '#!/bin/bash\n\
python3 github_action_entrypoint.py\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
PROPRIETARY SOFTWARE LICENSE

Licenstra™ Digital License Management System
© 2025 All Rights Reserved

NOTICE: This software is protected by copyright law and international treaties. 
Unauthorized reproduction or distribution of this program, or any portion of it, 
may result in severe civil and criminal penalties, and will be prosecuted to 
the maximum extent possible under the law.

RESTRICTIONS:
- No copying or redistribution
- No reverse engineering or decompilation
- No derivative works
- Commercial use restricted to license holder
- Source code is confidential and proprietary

DOMAIN RIGHTS:
licenstra.com and associated subdomains are protected trademarks.

For licensing inquiries: legal@licenstra.com
#!/usr/bin/env python3
"""
GitHub Action entrypoint for Licenstra License Generator
"""
import os
import sys
import uuid
import json
# GitHub Action uses simplified PDF generation
import tempfile
from fpdf import FPDF

def main():
    """Main entrypoint for GitHub Action"""
    try:
        # Get inputs from environment variables
        license_title = os.environ.get('LICENSE_TITLE', '')
        license_description = os.environ.get('LICENSE_DESCRIPTION', '')
        licensee_email = os.environ.get('LICENSEE_EMAIL', '')
        license_type = os.environ.get('LICENSE_TYPE', 'Commercial')
        language = os.environ.get('LANGUAGE', 'auto')
        
        if not all([license_title, license_description, licensee_email]):
            print("❌ Missing required inputs")
            sys.exit(1)
        
        # Auto-detect language if needed
        if language == 'auto':
            # Simple language detection based on email domain
            domain = licensee_email.split('@')[-1].lower()
            if domain.endswith('.se'):
                language = 'sv'
            elif domain.endswith('.de'):
                language = 'de'
            elif domain.endswith('.es'):
                language = 'es'
            elif domain.endswith('.fr'):
                language = 'fr'
            else:
                language = 'en'
        
        # Generate unique license ID
        license_id = f"GH-{str(uuid.uuid4())[:8].upper()}"
        
        # Generate PDF license
        pdf_path = f"/tmp/{license_id}.pdf"
        success = generate_simple_license_pdf(
            title=license_title,
            description=license_description,
            email=licensee_email,
            license_type=license_type,
            language=language,
            license_id=license_id,
            output_path=pdf_path
        )
        
        if not success:
            print("❌ Failed to generate license PDF")
            sys.exit(1)
        
        # Set outputs for GitHub Action
        github_output = os.environ.get('GITHUB_OUTPUT')
        if github_output:
            with open(github_output, 'a') as f:
                f.write(f"license_id={license_id}\n")
                f.write(f"pdf_url=file://{pdf_path}\n")
                f.write(f"verification_url=https://licenstra.replit.app/verify/{license_id}\n")
        
        print(f"✅ License generated successfully!")
        print(f"📄 License ID: {license_id}")
        print(f"📧 Licensee: {licensee_email}")
        print(f"🌍 Language: {language}")
        print(f"📁 PDF saved to: {pdf_path}")
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        sys.exit(1)

def generate_simple_license_pdf(title, description, email, license_type, language, license_id, output_path):
    """Generate a simple PDF license for GitHub Action"""
    try:
        pdf = FPDF()
        pdf.add_page()
        pdf.set_font('Arial', 'B', 16)
        
        # Header
        pdf.cell(0, 10, 'LICENSTRA DIGITAL LICENSE', 0, 1, 'C')
        pdf.ln(10)
        
        # License details
        pdf.set_font('Arial', 'B', 12)
        pdf.cell(0, 10, f'License ID: {license_id}', 0, 1)
        pdf.cell(0, 10, f'Title: {title}', 0, 1)
        pdf.cell(0, 10, f'Type: {license_type}', 0, 1)
        pdf.cell(0, 10, f'Licensee: {email}', 0, 1)
        pdf.ln(10)
        
        # Description
        pdf.set_font('Arial', '', 10)
        pdf.multi_cell(0, 10, f'Description: {description}')
        
        # Footer
        pdf.ln(10)
        pdf.set_font('Arial', 'I', 8)
        pdf.cell(0, 10, 'Generated by Licenstra - Professional Digital License Management', 0, 1, 'C')
        
        pdf.output(output_path)
        return True
    except Exception as e:
        print(f"PDF generation error: {e}")
        return False

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
Global PDF License Generator for Licenstra
Automatically generates licenses in user's language
"""

from fpdf import FPDF
from typing import Dict, Optional
import os
from PIL import Image
from localization import get_text, get_user_language

class GlobalLicensePDF(FPDF):
    """PDF generator with multi-language support"""
    
    def __init__(self, language: str = 'en'):
        super().__init__()
        self.language = language
        
    def header(self):
        # Logo handling
        logo_path = 'logo.png'
        if os.path.exists(logo_path):
            try:
                # Verify image can be opened
                with Image.open(logo_path) as img:
                    self.image(logo_path, 10, 8, 33)
            except Exception:
                # Fallback to text header
                self.set_font('Arial', 'B', 20)
                self.cell(0, 10, 'LICENSTRA', 0, 1, 'L')
        else:
            # Text header fallback
            self.set_font('Arial', 'B', 20)
            self.cell(0, 10, 'LICENSTRA', 0, 1, 'L')
        
        self.ln(10)

def generate_license_pdf(license_data: Dict, output_path: str, language: str = 'en') -> bool:
    """
    Generate PDF license certificate in specified language
    """
    try:
        # Create PDF with language support
        pdf = GlobalLicensePDF(language=language)
        pdf.add_page()
        
        # Get localized text
        title_text = get_text('certificate_title', language)
        if title_text == 'certificate_title':  # Fallback if key not found
            title_text = get_certificate_title(language)
        
        # Header section
        pdf.set_font('Arial', 'B', 24)
        pdf.cell(0, 15, title_text, 0, 1, 'C')
        pdf.ln(10)
        
        # License ID section
        pdf.set_font('Arial', 'B', 12)
        id_label = get_license_label('license_id', language)
        pdf.cell(50, 8, f"{id_label}:", 0, 0, 'L')
        pdf.set_font('Arial', '', 12)
        pdf.cell(0, 8, license_data.get('license_id', 'N/A'), 0, 1, 'L')
        pdf.ln(5)
        
        # License details section
        pdf.set_font('Arial', 'B', 16)
        details_title = get_license_label('license_details', language)
        pdf.cell(0, 10, details_title, 0, 1, 'L')
        pdf.ln(5)
        
        # Title
        pdf.set_font('Arial', 'B', 12)
        title_label = get_license_label('title', language)
        pdf.cell(50, 8, f"{title_label}:", 0, 0, 'L')
        pdf.set_font('Arial', '', 12)
        pdf.cell(0, 8, license_data.get('title', 'N/A'), 0, 1, 'L')
        
        # Type
        pdf.set_font('Arial', 'B', 12)
        type_label = get_license_label('type', language)
        pdf.cell(50, 8, f"{type_label}:", 0, 0, 'L')
        pdf.set_font('Arial', '', 12)
        license_type = translate_license_type(license_data.get('license_type', 'Standard'), language)
        pdf.cell(0, 8, license_type, 0, 1, 'L')
        
        # Owner
        pdf.set_font('Arial', 'B', 12)
        owner_label = get_license_label('owner', language)
        pdf.cell(50, 8, f"{owner_label}:", 0, 0, 'L')
        pdf.set_font('Arial', '', 12)
        pdf.cell(0, 8, license_data.get('owner_email', 'N/A'), 0, 1, 'L')
        
        # Creation date
        pdf.set_font('Arial', 'B', 12)
        date_label = get_license_label('created', language)
        pdf.cell(50, 8, f"{date_label}:", 0, 0, 'L')
        pdf.set_font('Arial', '', 12)
        pdf.cell(0, 8, license_data.get('created_at', 'N/A'), 0, 1, 'L')
        pdf.ln(10)
        
        # Description section
        if license_data.get('description'):
            pdf.set_font('Arial', 'B', 14)
            desc_title = get_license_label('description', language)
            pdf.cell(0, 10, desc_title, 0, 1, 'L')
            pdf.set_font('Arial', '', 11)
            
            # Multi-line description
            description = license_data.get('description', '')
            pdf.multi_cell(0, 6, description)
            pdf.ln(10)
        
        # Legal disclaimer section
        pdf.set_font('Arial', 'B', 14)
        legal_title = get_license_label('legal_disclaimer', language)
        pdf.cell(0, 10, legal_title, 0, 1, 'L')
        pdf.set_font('Arial', '', 10)
        
        disclaimer_text = get_legal_disclaimer(language)
        pdf.multi_cell(0, 5, disclaimer_text)
        pdf.ln(10)
        
        # Verification section
        pdf.set_font('Arial', 'B', 12)
        verify_title = get_license_label('verification', language)
        pdf.cell(0, 8, verify_title, 0, 1, 'L')
        pdf.set_font('Arial', '', 10)
        
        verify_text = get_verification_text(language, license_data.get('license_id', ''))
        pdf.multi_cell(0, 5, verify_text)
        
        # Footer with timestamp
        pdf.ln(20)
        pdf.set_font('Arial', 'I', 8)
        generated_text = get_license_label('generated', language)
        import datetime
        timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')
        pdf.cell(0, 5, f"{generated_text}: {timestamp}", 0, 0, 'C')
        
        # Save PDF
        pdf.output(output_path)
        return True
        
    except Exception as e:
        print(f"Error generating PDF: {e}")
        return False

def get_certificate_title(language: str) -> str:
    """Get certificate title in specified language"""
    titles = {
        'en': 'DIGITAL LICENSE CERTIFICATE',
        'sv': 'DIGITAL LICENSCERTIFIKAT',
        'es': 'CERTIFICADO DE LICENCIA DIGITAL',
        'de': 'DIGITALES LIZENZZERTIFIKAT',
        'fr': 'CERTIFICAT DE LICENCE NUMÉRIQUE'
    }
    return titles.get(language, titles['en'])

def get_license_label(key: str, language: str) -> str:
    """Get license field labels in specified language"""
    labels = {
        'en': {
            'license_id': 'License ID',
            'license_details': 'License Details',
            'title': 'Title',
            'type': 'License Type',
            'owner': 'Licensed to',
            'created': 'Created',
            'description': 'Description',
            'legal_disclaimer': 'Legal Disclaimer',
            'verification': 'Verification',
            'generated': 'Generated'
        },
        'sv': {
            'license_id': 'Licens-ID',
            'license_details': 'Licensdetaljer',
            'title': 'Titel',
            'type': 'Licenstyp',
            'owner': 'Licensierad till',
            'created': 'Skapad',
            'description': 'Beskrivning',
            'legal_disclaimer': 'Juridisk ansvarsfriskrivning',
            'verification': 'Verifiering',
            'generated': 'Genererad'
        },
        'es': {
            'license_id': 'ID de Licencia',
            'license_details': 'Detalles de Licencia',
            'title': 'Título',
            'type': 'Tipo de Licencia',
            'owner': 'Licenciado a',
            'created': 'Creado',
            'description': 'Descripción',
            'legal_disclaimer': 'Descargo de Responsabilidad Legal',
            'verification': 'Verificación',
            'generated': 'Generado'
        },
        'de': {
            'license_id': 'Lizenz-ID',
            'license_details': 'Lizenzdetails',
            'title': 'Titel',
            'type': 'Lizenztyp',
            'owner': 'Lizenziert an',
            'created': 'Erstellt',
            'description': 'Beschreibung',
            'legal_disclaimer': 'Rechtlicher Haftungsausschluss',
            'verification': 'Verifizierung',
            'generated': 'Generiert'
        },
        'fr': {
            'license_id': 'ID de Licence',
            'license_details': 'Détails de la Licence',
            'title': 'Titre',
            'type': 'Type de Licence',
            'owner': 'Licencié à',
            'created': 'Créé',
            'description': 'Description',
            'legal_disclaimer': 'Avertissement Légal',
            'verification': 'Vérification',
            'generated': 'Généré'
        }
    }
    return labels.get(language, labels['en']).get(key, key)

def translate_license_type(license_type: str, language: str) -> str:
    """Translate license type to specified language"""
    types = {
        'en': {
            'Standard': 'Standard License',
            'Commercial': 'Commercial License',
            'Extended': 'Extended License',
            'Exclusive': 'Exclusive License'
        },
        'sv': {
            'Standard': 'Standardlicens',
            'Commercial': 'Kommersiell licens',
            'Extended': 'Utökad licens',
            'Exclusive': 'Exklusiv licens'
        },
        'es': {
            'Standard': 'Licencia Estándar',
            'Commercial': 'Licencia Comercial',
            'Extended': 'Licencia Extendida',
            'Exclusive': 'Licencia Exclusiva'
        },
        'de': {
            'Standard': 'Standard-Lizenz',
            'Commercial': 'Kommerzielle Lizenz',
            'Extended': 'Erweiterte Lizenz',
            'Exclusive': 'Exklusive Lizenz'
        },
        'fr': {
            'Standard': 'Licence Standard',
            'Commercial': 'Licence Commerciale',
            'Extended': 'Licence Étendue',
            'Exclusive': 'Licence Exclusive'
        }
    }
    return types.get(language, types['en']).get(license_type, license_type)

def get_legal_disclaimer(language: str) -> str:
    """Get legal disclaimer in specified language"""
    disclaimers = {
        'en': """This digital license certificate is legally binding and grants specific usage rights as outlined above. The licensee agrees to use the licensed content strictly within the terms specified. Violation of these terms may result in legal action. This certificate is generated automatically by Licenstra's secure digital licensing platform and is valid for verification purposes. For disputes or clarifications, please refer to our terms of service.""",
        
        'sv': """Detta digitala licenscertifikat är juridiskt bindande och beviljar specifika användningsrättigheter enligt ovan. Licenstagaren går med på att använda det licensierade innehållet strikt inom de angivna villkoren. Överträdelse av dessa villkor kan resultera i rättsliga åtgärder. Detta certifikat genereras automatiskt av Licenstras säkra digitala licensplattform och är giltigt för verifieringssyften. För tvister eller förtydliganden, se våra användarvillkor.""",
        
        'es': """Este certificado de licencia digital es legalmente vinculante y otorga derechos de uso específicos como se describe arriba. El licenciatario acepta usar el contenido licenciado estrictamente dentro de los términos especificados. La violación de estos términos puede resultar en acción legal. Este certificado es generado automáticamente por la plataforma de licencias digitales segura de Licenstra y es válido para propósitos de verificación. Para disputas o aclaraciones, consulte nuestros términos de servicio.""",
        
        'de': """Dieses digitale Lizenzzertifikat ist rechtlich bindend und gewährt spezifische Nutzungsrechte wie oben beschrieben. Der Lizenznehmer erklärt sich damit einverstanden, den lizenzierten Inhalt strikt innerhalb der angegebenen Bedingungen zu nutzen. Die Verletzung dieser Bedingungen kann rechtliche Schritte zur Folge haben. Dieses Zertifikat wird automatisch von Licenstras sicherer digitaler Lizenzplattform generiert und ist für Verifizierungszwecke gültig. Für Streitigkeiten oder Klarstellungen beziehen Sie sich bitte auf unsere Nutzungsbedingungen.""",
        
        'fr': """Ce certificat de licence numérique est légalement contraignant et accorde des droits d'utilisation spécifiques comme décrit ci-dessus. Le licencié accepte d'utiliser le contenu licencié strictement dans les termes spécifiés. La violation de ces termes peut entraîner une action en justice. Ce certificat est généré automatiquement par la plateforme de licence numérique sécurisée de Licenstra et est valide à des fins de vérification. Pour les litiges ou clarifications, veuillez vous référer à nos conditions de service."""
    }
    return disclaimers.get(language, disclaimers['en'])

def get_verification_text(language: str, license_id: str) -> str:
    """Get verification instructions in specified language"""
    base_texts = {
        'en': f"To verify this license, visit https://licenstra.com/verify/{license_id} or use our API endpoint. This certificate contains a unique digital signature and can be authenticated at any time through our verification system.",
        'sv': f"För att verifiera denna licens, besök https://licenstra.com/verify/{license_id} eller använd vår API-slutpunkt. Detta certifikat innehåller en unik digital signatur och kan autentiseras när som helst genom vårt verifieringssystem.",
        'es': f"Para verificar esta licencia, visite https://licenstra.com/verify/{license_id} o use nuestro endpoint de API. Este certificado contiene una firma digital única y puede ser autenticado en cualquier momento a través de nuestro sistema de verificación.",
        'de': f"Um diese Lizenz zu verifizieren, besuchen Sie https://licenstra.com/verify/{license_id} oder verwenden Sie unseren API-Endpunkt. Dieses Zertifikat enthält eine einzigartige digitale Signatur und kann jederzeit über unser Verifizierungssystem authentifiziert werden.",
        'fr': f"Pour vérifier cette licence, visitez https://licenstra.com/verify/{license_id} ou utilisez notre point de terminaison API. Ce certificat contient une signature numérique unique et peut être authentifié à tout moment via notre système de vérification."
    }
    return base_texts.get(language, base_texts['en'])

def detect_user_language(email: str, user_agent: str = '', accept_language: str = '') -> str:
    """Detect user language from various indicators"""
    
    # Check email domain for country indication
    email_domain = email.split('@')[-1].lower()
    domain_languages = {
        '.se': 'sv',  # Sweden
        '.es': 'es',  # Spain
        '.de': 'de',  # Germany
        '.fr': 'fr',  # France
        '.uk': 'en',  # UK
        '.com': 'en', # Default to English for .com
    }
    
    for domain, lang in domain_languages.items():
        if domain in email_domain:
            return lang
    
    # Check Accept-Language header
    if accept_language:
        accept_lower = accept_language.lower()
        if 'sv' in accept_lower:
            return 'sv'
        elif 'es' in accept_lower:
            return 'es'
        elif 'de' in accept_lower:
            return 'de'
        elif 'fr' in accept_lower:
            return 'fr'
    
    # Default to English
    return 'en'

if __name__ == "__main__":
    # Test PDF generation in different languages
    test_data = {
        'license_id': 'TEST-123-456',
        'title': 'Test License Certificate',
        'license_type': 'Commercial',
        'owner_email': 'test@example.com',
        'created_at': '2025-08-01',
        'description': 'This is a test license for demonstrating multi-language PDF generation capabilities.'
    }
    
    print("🌍 TESTING MULTI-LANGUAGE PDF GENERATION")
    print("=" * 50)
    
    languages = ['en', 'sv', 'es', 'de', 'fr']
    for lang in languages:
        output_file = f"test_license_{lang}.pdf"
        success = generate_license_pdf(test_data, output_file, lang)
        print(f"  {lang.upper()}: {'✅ Generated' if success else '❌ Failed'} - {output_file}")
    
    print(f"\n✅ Multi-language PDF system ready!")
#!/usr/bin/env python3
"""
Licenstra Localization System
Global language support with English as default
"""

LANGUAGES = {
    'en': {
        'name': 'English',
        'code': 'en',
        'flag': '🇺🇸',
        'default': True
    },
    'sv': {
        'name': 'Svenska',
        'code': 'sv', 
        'flag': '🇸🇪'
    },
    'es': {
        'name': 'Español',
        'code': 'es',
        'flag': '🇪🇸'
    },
    'de': {
        'name': 'Deutsch',
        'code': 'de',
        'flag': '🇩🇪'
    },
    'fr': {
        'name': 'Français',
        'code': 'fr',
        'flag': '🇫🇷'
    }
}

TRANSLATIONS = {
    'en': {
        # Main interface
        'app_title': 'Licenstra - Digital License Management',
        'tagline': 'Professional Digital Licensing - Secure & Simple',
        'no_support_banner': 'AUTOMATED SERVICE - NO MANUAL SUPPORT AVAILABLE',
        'pricing_link': 'View pricing and purchase subscription here',
        
        # Tabs
        'create_license': 'Create License',
        'verify_license': 'Verify License',
        
        # Form labels
        'license_name': 'License Name',
        'license_name_placeholder': 'e.g. Photo License, Music Rights...',
        'description': 'Description',
        'description_placeholder': 'Describe what this license covers...',
        'your_email': 'Your Email',
        'email_placeholder': 'your.email@example.com',
        'license_type': 'License Type',
        'license_type_placeholder': 'Choose license type',
        
        # License types
        'license_standard': 'Standard License',
        'license_commercial': 'Commercial License',
        'license_extended': 'Extended License',
        'license_exclusive': 'Exclusive License',
        
        # Buttons
        'generate_license': 'Generate License',
        'verify_license_btn': 'Verify License',
        
        # Messages
        'generating': 'Generating your license...',
        'verifying': 'Verifying license...',
        'success_created': 'License created successfully!',
        'success_verified': 'License verified successfully!',
        'error_quota': 'License quota exceeded. Upgrade required.',
        'error_invalid': 'Invalid license ID or license not found.',
        
        # Pricing
        'pricing_title': 'Licenstra - Automated Digital Licensing',
        'no_support_pricing': 'NO MANUAL SUPPORT AVAILABLE',
        'pricing_subtitle': 'System is fully automated. Pay and get exactly what is promised - nothing more, nothing less.',
        'monthly': 'per month',
        'roi_label': 'ROI',
        'saves_label': 'Saves',
        'purchase_basic': 'Purchase BASIC',
        'purchase_professional': 'Purchase PROFESSIONAL',
        'purchase_enterprise': 'Purchase ENTERPRISE',
        
        # Features
        'features_basic': [
            '10 licenses per month',
            'Professional PDF certificates',
            'Legal disclaimers included',
            'Automatic email delivery',
            'Multi-language interface'
        ],
        'features_professional': [
            '50 licenses per month',
            'All BASIC features',
            'Custom logo on certificates',
            'Priority processing',
            'Monthly reports'
        ],
        'features_enterprise': [
            '500 licenses per month',
            'All PROFESSIONAL features',
            'API access',
            'Custom legal disclaimers',
            'White-label capabilities'
        ]
    },
    
    'sv': {
        # Main interface
        'app_title': 'Licenstra - Digital Licenshantering',
        'tagline': 'Professionell Digital Licensing - Säker & Enkel',
        'no_support_banner': 'AUTOMATISK SERVICE - INGEN MANUELL SUPPORT TILLGÄNGLIG',
        'pricing_link': 'Se priser och köp abonnemang här',
        
        # Tabs
        'create_license': 'Skapa Licens',
        'verify_license': 'Verifiera Licens',
        
        # Form labels
        'license_name': 'Licensnamn',
        'license_name_placeholder': 't.ex. Fotolicens, Musikrättigheter...',
        'description': 'Beskrivning',
        'description_placeholder': 'Beskriv vad licensen gäller för...',
        'your_email': 'Din E-post',
        'email_placeholder': 'din.epost@exempel.se',
        'license_type': 'Licenstyp',
        'license_type_placeholder': 'Välj licenstyp',
        
        # License types
        'license_standard': 'Standard Licens',
        'license_commercial': 'Kommersiell Licens',
        'license_extended': 'Utökad Licens',
        'license_exclusive': 'Exklusiv Licens',
        
        # Buttons
        'generate_license': 'Generera Licens',
        'verify_license_btn': 'Verifiera Licens',
        
        # Messages
        'generating': 'Genererar din licens...',
        'verifying': 'Verifierar licens...',
        'success_created': 'Licens skapad framgångsrikt!',
        'success_verified': 'Licens verifierad framgångsrikt!',
        'error_quota': 'Licenskvot överskred. Uppgradering krävs.',
        'error_invalid': 'Ogiltigt licens-ID eller licens hittades inte.',
        
        # Pricing
        'pricing_title': 'Licenstra - Automatisk Digital Licensing',
        'no_support_pricing': 'INGEN MANUELL SUPPORT TILLGÄNGLIG',
        'pricing_subtitle': 'Systemet är helt automatiskt. Betala och få exakt vad som utlovas - inget mer, inget mindre.',
        'monthly': 'per månad',
        'roi_label': 'ROI',
        'saves_label': 'Sparar',
        'purchase_basic': 'Köp BASIC',
        'purchase_professional': 'Köp PROFESSIONAL',
        'purchase_enterprise': 'Köp ENTERPRISE'
    }
}

def get_text(key: str, language: str = 'en') -> str:
    """Get translated text for given key and language"""
    if language not in TRANSLATIONS:
        language = 'en'
    
    return TRANSLATIONS[language].get(key, TRANSLATIONS['en'].get(key, key))

def get_user_language(request) -> str:
    """Detect user language from request headers"""
    # Check Accept-Language header
    accept_language = request.headers.get('Accept-Language', 'en')
    
    # Parse the language preference
    if 'sv' in accept_language.lower():
        return 'sv'
    elif 'es' in accept_language.lower():
        return 'es'
    elif 'de' in accept_language.lower():
        return 'de'
    elif 'fr' in accept_language.lower():
        return 'fr'
    else:
        return 'en'  # Default to English

def format_currency(amount: float, currency: str = 'USD') -> str:
    """Format currency for different regions"""
    if currency.upper() == 'USD':
        return f"${amount:.2f}"
    elif currency.upper() == 'SEK':
        return f"{amount:.0f} SEK"
    elif currency.upper() == 'EUR':
        return f"€{amount:.2f}"
    else:
        return f"{amount:.2f} {currency}"

if __name__ == "__main__":
    print("🌍 LICENSTRA LOCALIZATION SYSTEM")
    print("=" * 50)
    
    print("\n📋 SUPPORTED LANGUAGES:")
    for code, lang in LANGUAGES.items():
        default = " (Default)" if lang.get('default') else ""
        print(f"  {lang['flag']} {lang['name']} ({code}){default}")
    
    print(f"\n🔤 TRANSLATION KEYS:")
    en_keys = list(TRANSLATIONS['en'].keys())
    print(f"  Total keys: {len(en_keys)}")
    print(f"  Sample: {en_keys[:5]}")
    
    print(f"\n✅ System ready for global deployment!")
