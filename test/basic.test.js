/**
 * Basic test suite for the root project
 */

describe('Root project health', () => {
  test('should pass basic health check', () => {
    expect(true).toBe(true);
  });

  test('should have package.json', () => {
    const packageJson = require('./package.json');
    expect(packageJson.name).toBe('wix-studio-agency');
    expect(packageJson.version).toBeTruthy();
  });

  test('should have workspace configuration', () => {
    const packageJson = require('./package.json');
    expect(packageJson.workspaces).toContain('packages/*');
  });
});
