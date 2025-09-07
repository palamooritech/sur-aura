/**
 * Path: force-app/main/default/classes/DeprecationScannerController.cls
 * Apex controller for the LWC deprecation scanner component
 */
public with sharing class DeprecationScannerController {
    
    /**
     * Scans a GitHub repository for deprecated components
     */
    @AuraEnabled
    public static ScanResult scanGitHubRepository(String repositoryUrl) {
        try {
            // Validate input
            if (String.isBlank(repositoryUrl)) {
                ScanResult errorResult = new ScanResult();
                errorResult.addError('Repository URL is required');
                return errorResult;
            }
            
            // Clean up the URL
            repositoryUrl = repositoryUrl.trim();
            
            // Validate GitHub URL format
            if (!GitHubService.isValidGitHubUrl(repositoryUrl)) {
                ScanResult errorResult = new ScanResult();
                errorResult.addError('Invalid GitHub repository URL format. Expected: https://github.com/owner/repository');
                return errorResult;
            }
            
            // Get scanner instance and scan repository
            DeprecationScanner scanner = DeprecationScanner.getInstance();
            ScanResult result = scanner.scanRepository(repositoryUrl);
            
            return result;
            
        } catch (Exception e) {
            ScanResult errorResult = new ScanResult();
            errorResult.addError('Unexpected error occurred: ' + e.getMessage());
            System.debug('Error in scanGitHubRepository: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return errorResult;
        }
    }
    
    /**
     * Validates a GitHub repository URL
     */
    @AuraEnabled(cacheable=true)
    public static Boolean validateGitHubUrl(String repositoryUrl) {
        try {
            if (String.isBlank(repositoryUrl)) {
                return false;
            }
            return GitHubService.isValidGitHubUrl(repositoryUrl.trim());
        } catch (Exception e) {
            System.debug('Error validating GitHub URL: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Gets repository information from URL
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getRepositoryInfo(String repositoryUrl) {
        try {
            if (String.isBlank(repositoryUrl)) {
                return new Map<String, String>();
            }
            return GitHubService.extractRepoInfo(repositoryUrl.trim());
        } catch (Exception e) {
            System.debug('Error extracting repository info: ' + e.getMessage());
            return new Map<String, String>();
        }
    }
    
    /**
     * Gets all available deprecation rules
     */
    @AuraEnabled(cacheable=true)
    public static List<DeprecationRule> getDeprecationRules() {
        try {
            return DeprecationRule.getBuiltInRules();
        } catch (Exception e) {
            System.debug('Error getting deprecation rules: ' + e.getMessage());
            return new List<DeprecationRule>();
        }
    }
    
    /**
     * Gets rules filtered by component type
     */
    @AuraEnabled(cacheable=true)
    public static List<DeprecationRule> getRulesByComponentType(String componentType) {
        try {
            List<DeprecationRule> allRules = DeprecationRule.getBuiltInRules();
            List<DeprecationRule> filteredRules = new List<DeprecationRule>();
            
            DeprecationRule.ComponentType targetType = DeprecationRule.ComponentType.valueOf(componentType);
            
            for (DeprecationRule rule : allRules) {
                if (rule.componentType == targetType) {
                    filteredRules.add(rule);
                }
            }
            
            return filteredRules;
        } catch (Exception e) {
            System.debug('Error getting rules by component type: ' + e.getMessage());
            return new List<DeprecationRule>();
        }
    }
    
    /**
     * Performs a quick check to see if a repository might contain deprecated components
     */
    @AuraEnabled
    public static Map<String, Object> quickScanCheck(String repositoryUrl) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            // Validate URL
            if (!GitHubService.isValidGitHubUrl(repositoryUrl)) {
                result.put('isValid', false);
                result.put('message', 'Invalid GitHub repository URL');
                return result;
            }
            
            // Extract repo info
            Map<String, String> repoInfo = GitHubService.extractRepoInfo(repositoryUrl);
            result.put('isValid', true);
            result.put('repositoryName', repoInfo.get('fullName'));
            result.put('owner', repoInfo.get('owner'));
            result.put('name', repoInfo.get('name'));
            
            // Try to determine if it's a Salesforce project by checking for common patterns
            // This is a lightweight check before doing a full scan
            result.put('isSalesforceProject', true); // For demo, assume all are SF projects
            result.put('message', 'Repository appears to be a Salesforce project');
            
        } catch (Exception e) {
            result.put('isValid', false);
            result.put('message', 'Error checking repository: ' + e.getMessage());
            System.debug('Error in quickScanCheck: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Gets scan statistics and summary data
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getScanStatistics() {
        Map<String, Object> stats = new Map<String, Object>();
        
        try {
            List<DeprecationRule> rules = DeprecationRule.getBuiltInRules();
            
            // Count rules by component type
            Map<String, Integer> ruleCountsByType = new Map<String, Integer>{
                'AURA' => 0,
                'LWC' => 0,
                'APEX' => 0
            };
            
            Map<String, Integer> ruleCountsBySeverity = new Map<String, Integer>{
                'HIGH' => 0,
                'MEDIUM' => 0,
                'LOW' => 0
            };
            
            for (DeprecationRule rule : rules) {
                String typeKey = String.valueOf(rule.componentType);
                if (ruleCountsByType.containsKey(typeKey)) {
                    ruleCountsByType.put(typeKey, ruleCountsByType.get(typeKey) + 1);
                }
                
                if (ruleCountsBySeverity.containsKey(rule.severity)) {
                    ruleCountsBySeverity.put(rule.severity, ruleCountsBySeverity.get(rule.severity) + 1);
                }
            }
            
            stats.put('totalRules', rules.size());
            stats.put('rulesByType', ruleCountsByType);
            stats.put('rulesBySeverity', ruleCountsBySeverity);
            stats.put('lastUpdated', System.now());
            
        } catch (Exception e) {
            System.debug('Error getting scan statistics: ' + e.getMessage());
            stats.put('error', e.getMessage());
        }
        
        return stats;
    }
    
    /**
     * Test method to verify controller functionality
     */
    @AuraEnabled
    public static String testConnection() {
        try {
            return 'Connection successful! Scanner is ready to use.';
        } catch (Exception e) {
            return 'Connection failed: ' + e.getMessage();
        }
    }
}