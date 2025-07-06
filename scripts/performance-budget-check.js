#!/usr/bin/env node
/**
 * Performance Budget Validation Script
 * Checks if the application meets defined performance budgets
 */

const fs = require('fs');
const path = require('path');

class PerformanceBudgetChecker {
  constructor() {
    this.errors = [];
    this.warnings = [];
    
    // Default performance budgets
    this.budgets = {
      'api-services': {
        bundleSize: 5 * 1024 * 1024, // 5MB
        dependencies: 100,
        devDependencies: 200
      },
      'wix-websites': {
        bundleSize: 3 * 1024 * 1024, // 3MB
        dependencies: 50,
        devDependencies: 150
      },
      'internal-tools': {
        bundleSize: 10 * 1024 * 1024, // 10MB (React app)
        dependencies: 80,
        devDependencies: 200
      },
      'microservices': {
        // Python requirements
        dependencies: 30,
        imageSize: 500 * 1024 * 1024 // 500MB Docker image
      }
    };
    
    this.loadCustomBudgets();
  }
  
  loadCustomBudgets() {
    try {
      const budgetFile = path.join(process.cwd(), 'performance-budget.json');
      if (fs.existsSync(budgetFile)) {
        const customBudgets = JSON.parse(fs.readFileSync(budgetFile, 'utf8'));
        this.budgets = { ...this.budgets, ...customBudgets };
        console.log('✅ Loaded custom performance budgets');
      }
    } catch (error) {
      console.warn('⚠️  Could not load custom performance budgets:', error.message);
    }
  }
  
  checkPackage(packagePath) {
    try {
      const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
      const packageDir = path.dirname(packagePath);
      const packageName = path.basename(packageDir);
      
      console.log(`🔍 Checking performance budget for ${packageName}...`);
      
      if (!this.budgets[packageName]) {
        console.log(`ℹ️  No performance budget defined for ${packageName}, skipping...`);
        return true;
      }
      
      const budget = this.budgets[packageName];
      let passed = true;
      
      // Check dependency count
      if (budget.dependencies && packageJson.dependencies) {
        const depCount = Object.keys(packageJson.dependencies).length;
        if (depCount > budget.dependencies) {
          this.errors.push(
            `${packageName}: Too many dependencies (${depCount}/${budget.dependencies})`
          );
          passed = false;
        } else {
          console.log(`✅ Dependencies: ${depCount}/${budget.dependencies}`);
        }
      }
      
      // Check dev dependency count
      if (budget.devDependencies && packageJson.devDependencies) {
        const devDepCount = Object.keys(packageJson.devDependencies).length;
        if (devDepCount > budget.devDependencies) {
          this.warnings.push(
            `${packageName}: Many dev dependencies (${devDepCount}/${budget.devDependencies})`
          );
        } else {
          console.log(`✅ Dev Dependencies: ${devDepCount}/${budget.devDependencies}`);
        }
      }
      
      // Check for problematic dependencies
      this.checkProblematicDependencies(packageName, packageJson);
      
      // Check bundle size (if dist/build exists)
      if (budget.bundleSize) {
        this.checkBundleSize(packageName, packageDir, budget.bundleSize);
      }
      
      // Check for duplicate dependencies
      this.checkDuplicateDependencies(packageName, packageJson);
      
      return passed;
      
    } catch (error) {
      this.errors.push(`Error checking ${packagePath}: ${error.message}`);
      return false;
    }
  }
  
  checkProblematicDependencies(packageName, packageJson) {
    const problematicDeps = {
      'lodash': 'Consider using lodash-es or specific lodash functions',
      'moment': 'Consider using date-fns or dayjs for smaller bundle size',
      'axios': 'Consider using fetch API or a lighter HTTP client',
      'jquery': 'Avoid jQuery in modern applications',
      'left-pad': 'Security risk - use native string methods',
      'request': 'Deprecated - use axios or fetch',
      'debug': 'Should be in devDependencies only'
    };
    
    const deps = { ...packageJson.dependencies, ...packageJson.devDependencies };
    
    for (const [dep, suggestion] of Object.entries(problematicDeps)) {
      if (deps[dep]) {
        this.warnings.push(`${packageName}: ${dep} - ${suggestion}`);
      }
    }
  }
  
  checkBundleSize(packageName, packageDir, maxSize) {
    const buildDirs = ['dist', 'build', '.next'];
    
    for (const buildDir of buildDirs) {
      const buildPath = path.join(packageDir, buildDir);
      if (fs.existsSync(buildPath)) {
        const size = this.getDirectorySize(buildPath);
        if (size > maxSize) {
          this.errors.push(
            `${packageName}: Bundle size too large (${this.formatBytes(size)}/${this.formatBytes(maxSize)})`
          );
        } else {
          console.log(`✅ Bundle size: ${this.formatBytes(size)}/${this.formatBytes(maxSize)}`);
        }
        break;
      }
    }
  }
  
  checkDuplicateDependencies(packageName, packageJson) {
    const allDeps = {
      ...packageJson.dependencies,
      ...packageJson.devDependencies
    };
    
    // Check for common duplicate patterns
    const duplicatePatterns = [
      ['react', '@types/react'],
      ['express', '@types/express'],
      ['node', '@types/node'],
      ['jest', '@types/jest']
    ];
    
    for (const [dep, typeDep] of duplicatePatterns) {
      if (allDeps[dep] && allDeps[typeDep]) {
        // This is actually fine - types should be separate
        continue;
      }
    }
    
    // Check for actual duplicates with different versions
    const packageNames = Object.keys(allDeps);
    const duplicates = packageNames.filter((name, index) => 
      packageNames.indexOf(name) !== index
    );
    
    if (duplicates.length > 0) {
      this.warnings.push(
        `${packageName}: Potential duplicate dependencies: ${duplicates.join(', ')}`
      );
    }
  }
  
  getDirectorySize(dirPath) {
    let totalSize = 0;
    
    function calculateSize(currentPath) {
      const stats = fs.statSync(currentPath);
      
      if (stats.isDirectory()) {
        const files = fs.readdirSync(currentPath);
        for (const file of files) {
          calculateSize(path.join(currentPath, file));
        }
      } else {
        totalSize += stats.size;
      }
    }
    
    try {
      calculateSize(dirPath);
    } catch (error) {
      console.warn(`Warning: Could not calculate size for ${dirPath}`);
    }
    
    return totalSize;
  }
  
  formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }
  
  printResults() {
    console.log('\n' + '='.repeat(60));
    console.log('PERFORMANCE BUDGET CHECK RESULTS');
    console.log('='.repeat(60));
    
    if (this.errors.length > 0) {
      console.log('\n❌ ERRORS:');
      this.errors.forEach(error => console.log(`  ${error}`));
    }
    
    if (this.warnings.length > 0) {
      console.log('\n⚠️  WARNINGS:');
      this.warnings.forEach(warning => console.log(`  ${warning}`));
    }
    
    if (this.errors.length === 0 && this.warnings.length === 0) {
      console.log('\n✅ All performance budgets are within limits!');
    }
    
    if (this.errors.length > 0) {
      console.log('\n💡 Performance Optimization Tips:');
      console.log('  - Use tree-shaking to eliminate unused code');
      console.log('  - Consider code splitting for large applications');
      console.log('  - Use lighter alternatives for heavy dependencies');
      console.log('  - Enable gzip compression in production');
      console.log('  - Optimize images and static assets');
    }
    
    return this.errors.length === 0;
  }
}

function main() {
  const checker = new PerformanceBudgetChecker();
  
  // Find all package.json files in packages directory
  const packagesDir = path.join(process.cwd(), 'packages');
  
  if (!fs.existsSync(packagesDir)) {
    console.error('❌ packages directory not found');
    process.exit(1);
  }
  
  const packages = fs.readdirSync(packagesDir)
    .filter(item => fs.statSync(path.join(packagesDir, item)).isDirectory())
    .map(item => path.join(packagesDir, item, 'package.json'))
    .filter(packagePath => fs.existsSync(packagePath));
  
  if (packages.length === 0) {
    console.error('❌ No package.json files found');
    process.exit(1);
  }
  
  console.log(`🔍 Found ${packages.length} packages to check`);
  
  let allPassed = true;
  for (const packagePath of packages) {
    if (!checker.checkPackage(packagePath)) {
      allPassed = false;
    }
  }
  
  const success = checker.printResults();
  process.exit(success ? 0 : 1);
}

if (require.main === module) {
  main();
}

module.exports = PerformanceBudgetChecker;
