#!/usr/bin/env python3
"""
Azure Configuration Security and Best Practices Checker
Validates Azure Bicep templates against security best practices
"""

import json
import sys
import re
from pathlib import Path
from typing import List, Dict, Any

class AzureConfigChecker:
    def __init__(self):
        self.errors = []
        self.warnings = []
        
        # Security best practices rules
        self.security_rules = {
            'key_vault_access_policies': {
                'pattern': r'accessPolicies.*permissions.*secrets.*\[.*get.*list.*\]',
                'message': 'Key Vault should use least privilege access policies',
                'severity': 'warning'
            },
            'storage_account_secure_transfer': {
                'pattern': r'supportsHttpsTrafficOnly.*true',
                'message': 'Storage accounts should require secure transfer (HTTPS)',
                'severity': 'error',
                'required': True
            },
            'app_service_https_only': {
                'pattern': r'httpsOnly.*true',
                'message': 'App Services should enforce HTTPS only',
                'severity': 'error',
                'required': True
            },
            'managed_identity': {
                'pattern': r'identity.*type.*SystemAssigned|UserAssigned',
                'message': 'Resources should use managed identity instead of service principals',
                'severity': 'warning'
            },
            'network_security_groups': {
                'pattern': r'securityRules.*access.*Allow.*\*.*\*',
                'message': 'NSG rules should not allow unrestricted access (*:*)',
                'severity': 'error',
                'invert': True
            },
            'sql_server_firewall': {
                'pattern': r'firewallRules.*startIpAddress.*0\.0\.0\.0.*endIpAddress.*255\.255\.255\.255',
                'message': 'SQL Server should not allow unrestricted firewall access (0.0.0.0-255.255.255.255)',
                'severity': 'error',
                'invert': True
            }
        }
        
        # Naming convention rules
        self.naming_rules = {
            'resource_group': r'^rg-[a-z0-9-]+$',
            'storage_account': r'^st[a-z0-9]{3,22}$',
            'key_vault': r'^kv-[a-z0-9-]+$',
            'app_service': r'^app-[a-z0-9-]+$',
            'app_service_plan': r'^asp-[a-z0-9-]+$',
            'sql_server': r'^sql-[a-z0-9-]+$',
            'cosmos_db': r'^cosmos-[a-z0-9-]+$'
        }
    
    def check_file(self, file_path: str) -> bool:
        """Check a single Bicep file for security and best practices"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            print(f"Checking {file_path}...")
            
            # Check security rules
            self._check_security_rules(content, file_path)
            
            # Check naming conventions
            self._check_naming_conventions(content, file_path)
            
            # Check for hardcoded values
            self._check_hardcoded_values(content, file_path)
            
            # Check resource dependencies
            self._check_resource_dependencies(content, file_path)
            
            return len(self.errors) == 0
            
        except Exception as e:
            self.errors.append(f"Error reading {file_path}: {str(e)}")
            return False
    
    def _check_security_rules(self, content: str, file_path: str):
        """Check security-related rules"""
        for rule_name, rule_config in self.security_rules.items():
            pattern = rule_config['pattern']
            message = rule_config['message']
            severity = rule_config['severity']
            invert = rule_config.get('invert', False)
            required = rule_config.get('required', False)
            
            matches = re.search(pattern, content, re.IGNORECASE | re.DOTALL)
            
            if invert:
                # Rule should NOT match (e.g., no unrestricted access)
                if matches:
                    if severity == 'error':
                        self.errors.append(f"{file_path}: {message}")
                    else:
                        self.warnings.append(f"{file_path}: {message}")
            else:
                # Rule should match (e.g., HTTPS required)
                if not matches and required:
                    if severity == 'error':
                        self.errors.append(f"{file_path}: {message}")
                    else:
                        self.warnings.append(f"{file_path}: {message}")
    
    def _check_naming_conventions(self, content: str, file_path: str):
        """Check Azure resource naming conventions"""
        # Extract resource declarations
        resource_pattern = r"resource\s+(\w+)\s+'([^']+)'\s+=\s+{"
        resources = re.findall(resource_pattern, content)
        
        for resource_name, resource_type in resources:
            # Map resource types to naming rules
            type_mapping = {
                'Microsoft.Resources/resourceGroups': 'resource_group',
                'Microsoft.Storage/storageAccounts': 'storage_account',
                'Microsoft.KeyVault/vaults': 'key_vault',
                'Microsoft.Web/sites': 'app_service',
                'Microsoft.Web/serverfarms': 'app_service_plan',
                'Microsoft.Sql/servers': 'sql_server',
                'Microsoft.DocumentDB/databaseAccounts': 'cosmos_db'
            }
            
            naming_type = type_mapping.get(resource_type)
            if naming_type and naming_type in self.naming_rules:
                pattern = self.naming_rules[naming_type]
                
                # Find the name property
                name_pattern = f"name:\\s*'([^']+)'"
                name_match = re.search(name_pattern, content)
                
                if name_match:
                    resource_actual_name = name_match.group(1)
                    if not re.match(pattern, resource_actual_name):
                        self.warnings.append(
                            f"{file_path}: Resource '{resource_name}' of type '{resource_type}' "
                            f"should follow naming convention: {pattern}"
                        )
    
    def _check_hardcoded_values(self, content: str, file_path: str):
        """Check for hardcoded sensitive values"""
        hardcoded_patterns = [
            (r'password.*[:=].*[\'"][^\'"]{8,}[\'"]', 'Possible hardcoded password'),
            (r'connectionString.*[:=].*[\'"][^\'"]+[\'"]', 'Possible hardcoded connection string'),
            (r'apiKey.*[:=].*[\'"][^\'"]+[\'"]', 'Possible hardcoded API key'),
            (r'secret.*[:=].*[\'"][^\'"]+[\'"]', 'Possible hardcoded secret'),
            (r'token.*[:=].*[\'"][^\'"]+[\'"]', 'Possible hardcoded token')
        ]
        
        for pattern, message in hardcoded_patterns:
            if re.search(pattern, content, re.IGNORECASE):
                self.errors.append(f"{file_path}: {message}")
    
    def _check_resource_dependencies(self, content: str, file_path: str):
        """Check for proper resource dependencies"""
        # Check if resources that depend on Key Vault are properly configured
        if 'Microsoft.KeyVault/vaults' in content:
            # Ensure resources depending on Key Vault have proper access policies
            if 'Microsoft.Web/sites' in content or 'Microsoft.ContainerInstance/containerGroups' in content:
                if 'accessPolicies' not in content:
                    self.warnings.append(
                        f"{file_path}: Resources using Key Vault should have proper access policies defined"
                    )
        
        # Check for proper network configuration
        if 'Microsoft.Web/sites' in content:
            if 'vnetRouteAllEnabled' not in content:
                self.warnings.append(
                    f"{file_path}: App Services should consider VNet integration for enhanced security"
                )
    
    def print_results(self):
        """Print check results"""
        if self.errors:
            print("\n❌ ERRORS:")
            for error in self.errors:
                print(f"  {error}")
        
        if self.warnings:
            print("\n⚠️  WARNINGS:")
            for warning in self.warnings:
                print(f"  {warning}")
        
        if not self.errors and not self.warnings:
            print("\n✅ All checks passed!")
        
        return len(self.errors) == 0

def main():
    if len(sys.argv) < 2:
        print("Usage: python azure-config-check.py <file1> [file2] ...")
        sys.exit(1)
    
    checker = AzureConfigChecker()
    all_passed = True
    
    for file_path in sys.argv[1:]:
        if not file_path.endswith('.bicep'):
            continue
            
        if not checker.check_file(file_path):
            all_passed = False
    
    success = checker.print_results()
    
    if not success:
        print("\n💡 Tips:")
        print("  - Use Azure Key Vault for secrets management")
        print("  - Enable HTTPS-only for web applications")
        print("  - Use managed identities instead of service principals")
        print("  - Follow Azure naming conventions")
        print("  - Avoid hardcoded secrets in templates")
        
        sys.exit(1)
    
    sys.exit(0)

if __name__ == "__main__":
    main()
