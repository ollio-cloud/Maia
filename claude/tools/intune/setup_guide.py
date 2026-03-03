#!/usr/bin/env python3
"""
Interactive setup guide for Intune Policy Reporter
Helps collect and validate credentials, then saves them securely.
"""

import os
import sys
import json
from pathlib import Path

def print_header(text):
    """Print a formatted header."""
    print("\n" + "=" * 60)
    print(text)
    print("=" * 60 + "\n")

def print_step(step_num, text):
    """Print a step number and description."""
    print(f"\n📋 Step {step_num}: {text}")
    print("-" * 60)

def get_input(prompt, required=True):
    """Get user input with validation."""
    while True:
        value = input(f"{prompt}: ").strip()
        if value or not required:
            return value
        print("❌ This field is required. Please enter a value.")

def main():
    print_header("Intune Policy Reporter - Setup Guide")

    print("""
This guide will help you set up the Intune Policy Reporter tool.

You'll need to:
1. Create an Azure AD App Registration
2. Configure API permissions
3. Create a client secret
4. Save your credentials securely
    """)

    input("Press Enter to continue...")

    # Step 1: Azure AD App Registration
    print_step(1, "Azure AD App Registration")
    print("""
Create an Azure AD App Registration:

1. Go to: https://portal.azure.com
2. Navigate to: Azure Active Directory → App registrations
3. Click: "New registration"
4. Name: "Intune Policy Reporter" (or your choice)
5. Supported account types: "Accounts in this organizational directory only"
6. Click: "Register"

After registration, you'll see the "Overview" page with:
- Application (client) ID
- Directory (tenant) ID
    """)

    tenant_id = get_input("Enter your Tenant ID (Directory ID)")
    client_id = get_input("Enter your Client ID (Application ID)")

    # Step 2: API Permissions
    print_step(2, "Configure API Permissions")
    print("""
Add Microsoft Graph API permissions:

1. In your app registration, go to: "API permissions"
2. Click: "Add a permission"
3. Select: "Microsoft Graph"
4. Select: "Application permissions"
5. Add these permissions:
   ☐ DeviceManagementConfiguration.Read.All
   ☐ DeviceManagementApps.Read.All
   ☐ DeviceManagementManagedDevices.Read.All
6. Click: "Add permissions"
7. Click: "Grant admin consent for [Your Organization]"
8. Confirm: You should see green checkmarks next to each permission
    """)

    input("Press Enter once you've granted admin consent...")

    # Step 3: Client Secret
    print_step(3, "Create Client Secret")
    print("""
Create a client secret:

1. In your app registration, go to: "Certificates & secrets"
2. Click: "New client secret"
3. Description: "Intune Reporter Secret"
4. Expires: Choose duration (12-24 months recommended)
5. Click: "Add"
6. IMPORTANT: Copy the "Value" immediately (you can't see it again!)
    """)

    client_secret = get_input("Paste your Client Secret here")

    # Step 4: Save Configuration
    print_step(4, "Save Configuration")

    config_dir = Path.home() / ".intune_reporter"
    config_file = config_dir / "config.json"

    print(f"""
Your credentials will be saved to:
{config_file}

This file will be used by the reporter tool to authenticate.

SECURITY NOTES:
- This file contains sensitive credentials
- File permissions will be set to owner-only (600)
- Never commit this file to version control
- Add to .gitignore if using git
    """)

    save_config = input("Save configuration? (yes/no): ").lower().strip()

    if save_config in ['yes', 'y']:
        # Create config directory
        config_dir.mkdir(exist_ok=True)

        # Save configuration
        config = {
            "tenant_id": tenant_id,
            "client_id": client_id,
            "client_secret": client_secret,
            "prefix": "Orro"
        }

        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)

        # Set restrictive permissions (Unix-like systems)
        if os.name != 'nt':  # Not Windows
            os.chmod(config_file, 0o600)

        print(f"\n✅ Configuration saved to: {config_file}")

        # Create wrapper script
        script_dir = Path(__file__).parent
        wrapper_script = script_dir / "run_report.py"

        wrapper_content = f'''#!/usr/bin/env python3
"""
Wrapper script to run Intune Policy Reporter with saved credentials.
"""

import json
import subprocess
from pathlib import Path

config_file = Path.home() / ".intune_reporter" / "config.json"

if not config_file.exists():
    print("❌ Configuration file not found. Run setup_guide.py first.")
    exit(1)

with open(config_file) as f:
    config = json.load(f)

# Run the reporter
subprocess.run([
    "python",
    "{script_dir / 'intune_policy_reporter.py'}",
    "--tenant-id", config["tenant_id"],
    "--client-id", config["client_id"],
    "--client-secret", config["client_secret"],
    "--prefix", config.get("prefix", "Orro")
])
'''

        with open(wrapper_script, 'w') as f:
            f.write(wrapper_content)

        if os.name != 'nt':
            os.chmod(wrapper_script, 0o755)

        print(f"✅ Wrapper script created: {wrapper_script}")

        print_header("Setup Complete!")
        print("""
You're all set! To generate a report, run:

    python run_report.py

Or use the main script directly:

    python intune_policy_reporter.py \\
      --tenant-id YOUR_TENANT_ID \\
      --client-id YOUR_CLIENT_ID \\
      --client-secret YOUR_CLIENT_SECRET

The report will be saved as: Intune_Orro_Configuration_Report.docx
        """)

    else:
        print("\nConfiguration not saved.")
        print("\nTo run the reporter manually, use:")
        print(f"""
    python intune_policy_reporter.py \\
      --tenant-id {tenant_id} \\
      --client-id {client_id} \\
      --client-secret [YOUR_SECRET]
        """)

    print_header("Next Steps")
    print("""
1. Test the authentication by running the reporter
2. Review the generated Word document
3. Schedule regular reports if needed
4. Keep your client secret secure and rotate it regularly

For help and troubleshooting, see README.md
    """)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n❌ Setup cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Error: {e}")
        sys.exit(1)
