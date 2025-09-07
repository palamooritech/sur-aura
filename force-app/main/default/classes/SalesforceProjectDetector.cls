/**
 * Path: force-app/main/default/classes/SalesforceProjectDetector.cls
 * Utility class to detect if a repository contains a Salesforce application
 */
public with sharing class SalesforceProjectDetector {
    
    public class ProjectDetectionResult {
        public Boolean isSalesforceProject { get; set; }
        public String projectType { get; set; }
        public String reason { get; set; }
        public List<String> indicators { get; set; }
        public Integer confidence { get; set; } // 0-100
        
        public ProjectDetectionResult() {
            this.indicators = new List<String>();
            this.confidence = 0;
        }
    }
    
    // Salesforce DX project indicators
    private static final Set<String> SFDX_FILES = new Set<String>{
        'sfdx-project.json',
        '.sfdx/sfdx-config.json',
        'config/project-scratch-def.json'
    };
    
    // Legacy metadata API indicators
    private static final Set<String> LEGACY_FILES = new Set<String>{
        'src/package.xml',
        'package.xml',
        'destructiveChanges.xml',
        'destructiveChangesPre.xml',
        'destructiveChangesPost.xml'
    };
    
    // Salesforce directory structures
    private static final Set<String> SALESFORCE_DIRECTORIES = new Set<String>{
        'force-app/',
        'src/',
        '.sfdx/',
        'sfdx-out/',
        'mdapi-source/',
        'metadata/'
    };
    
    // Salesforce-specific file extensions with their confidence weights
    private static final Map<String, Integer> SALESFORCE_EXTENSIONS = new Map<String, Integer>{
        'cls' => 30,          // Apex classes
        'trigger' => 30,      // Apex triggers
        'cmp' => 25,          // Aura components
        'app' => 25,          // Aura applications
        'evt' => 20,          // Aura events
        'intf' => 20,         // Aura interfaces
        'auradoc' => 15,      // Aura documentation
        'design' => 15,       // Aura design files
        'svg' => 10,          // Aura SVG files (when in aura context)
        'page' => 25,         // Visualforce pages
        'component' => 25,    // Visualforce components
        'object' => 20,       // Custom objects
        'field' => 15,        // Custom fields
        'workflow' => 15,     // Workflow rules
        'flow' => 15,         // Flow definitions
        'permissionset' => 15, // Permission sets
        'profile' => 15,      // Profiles
        'layout' => 15,       // Page layouts
        'dashboard' => 10,    // Dashboards
        'report' => 10,       // Reports
        'email' => 10,        // Email templates
        'queue' => 10,        // Queues
        'group' => 10,        // Public groups
        'role' => 10,         // Roles
        'sharingRules' => 10, // Sharing rules
        'territory' => 10,    // Territory management
        'remoteSite' => 10,   // Remote site settings
        'customApplication' => 15, // Custom applications
        'tab' => 10,          // Custom tabs
        'labels' => 10,       // Custom labels
        'translation' => 10,  // Translations
        'staticresources' => 5 // Static resources
    };
    
    // Non-Salesforce project indicators (negative indicators)
    private static final Set<String> NON_SALESFORCE_INDICATORS = new Set<String>{
        'package.json',       // Node.js (unless in tools directory)
        'pom.xml',           // Maven/Java
        'build.gradle',      // Gradle
        'Gemfile',           // Ruby
        'requirements.txt',  // Python
        'composer.json',     // PHP
        'Cargo.toml',        // Rust
        'go.mod',           // Go
        'project.clj',      // Clojure
        'mix.exs'           // Elixir
    };
    
    /**
     * Main method to detect if extracted files represent a Salesforce project
     */
    public static ProjectDetectionResult detectSalesforceProject(List<ZipProcessor.ExtractedFile> files) {
        ProjectDetectionResult result = new ProjectDetectionResult();
        
        if (files == null || files.isEmpty()) {
            result.isSalesforceProject = false;
            result.reason = 'No files found in repository';
            return result;
        }
        
        // Check for explicit Salesforce project files
        checkExplicitIndicators(files, result);
        
        // Check directory structure
        checkDirectoryStructure(files, result);
        
        // Check file extensions and content
        checkFileExtensions(files, result);
        
        // Check for non-Salesforce indicators
        checkNonSalesforceIndicators(files, result);
        
        // Determine final result
        determineFinalResult(result);
        
        return result;
    }
    
    /**
     * Checks for explicit Salesforce project files
     */
    private static void checkExplicitIndicators(List<ZipProcessor.ExtractedFile> files, ProjectDetectionResult result) {
        for (ZipProcessor.ExtractedFile file : files) {
            String normalizedPath = file.path.toLowerCase();
            
            // Check for SFDX files
            for (String sfdxFile : SFDX_FILES) {
                if (normalizedPath.contains(sfdxFile.toLowerCase())) {
                    result.indicators.add('Found SFDX project file: ' + file.path);
                    result.confidence += 50;
                    result.projectType = 'Salesforce DX';
                }
            }
            
            // Check for legacy metadata files
            for (String legacyFile : LEGACY_FILES) {
                if (normalizedPath.contains(legacyFile.toLowerCase())) {
                    result.indicators.add('Found legacy metadata file: ' + file.path);
                    result.confidence += 40;
                    if (String.isBlank(result.projectType)) {
                        result.projectType = 'Legacy Metadata API';
                    }
                }
            }
            
            // Special check for sfdx-project.json content
            if (file.name.equalsIgnoreCase('sfdx-project.json') && String.isNotBlank(file.content)) {
                if (file.content.contains('packageDirectories') || file.content.contains('namespace')) {
                    result.indicators.add('Valid sfdx-project.json with Salesforce configuration');
                    result.confidence += 30;
                }
            }
        }
    }
    
    /**
     * Checks directory structure for Salesforce patterns
     */
    private static void checkDirectoryStructure(List<ZipProcessor.ExtractedFile> files, ProjectDetectionResult result) {
        Set<String> foundDirectories = new Set<String>();
        
        for (ZipProcessor.ExtractedFile file : files) {
            String path = file.path.toLowerCase();
            
            for (String sfDir : SALESFORCE_DIRECTORIES) {
                if (path.contains(sfDir.toLowerCase())) {
                    foundDirectories.add(sfDir);
                }
            }
            
            // Check for specific Salesforce subdirectories
            if (path.contains('/lwc/') || path.contains('/aura/') || 
                path.contains('/classes/') || path.contains('/triggers/') ||
                path.contains('/objects/') || path.contains('/layouts/')) {
                result.indicators.add('Found Salesforce metadata directory structure');
                result.confidence += 20;
            }
        }
        
        // Bonus points for multiple Salesforce directories
        if (foundDirectories.size() > 1) {
            result.indicators.add('Multiple Salesforce directories found: ' + String.join(new List<String>(foundDirectories), ', '));
            result.confidence += 15;
        }
    }
    
    /**
     * Checks file extensions for Salesforce-specific types
     */
    private static void checkFileExtensions(List<ZipProcessor.ExtractedFile> files, ProjectDetectionResult result) {
        Map<String, Integer> extensionCounts = new Map<String, Integer>();
        Integer salesforceFileCount = 0;
        
        for (ZipProcessor.ExtractedFile file : files) {
            String ext = file.extension.toLowerCase();
            
            if (SALESFORCE_EXTENSIONS.containsKey(ext)) {
                salesforceFileCount++;
                
                if (extensionCounts.containsKey(ext)) {
                    extensionCounts.put(ext, extensionCounts.get(ext) + 1);
                } else {
                    extensionCounts.put(ext, 1);
                }
                
                // Add confidence based on extension weight
                Integer weight = SALESFORCE_EXTENSIONS.get(ext);
                result.confidence += weight;
            }
            
            // Special handling for JavaScript files in LWC context
            if (ext == 'js' && (file.path.contains('/lwc/') || 
                isLWCJavaScript(file.content))) {
                result.indicators.add('Found LWC JavaScript file: ' + file.path);
                result.confidence += 20;
                salesforceFileCount++;
            }
        }
        
        if (salesforceFileCount > 0) {
            result.indicators.add('Found ' + salesforceFileCount + ' Salesforce-specific files');
            
            // List the most common extensions found
            List<String> commonExtensions = new List<String>();
            for (String ext : extensionCounts.keySet()) {
                if (extensionCounts.get(ext) > 1) {
                    commonExtensions.add(ext + '(' + extensionCounts.get(ext) + ')');
                }
            }
            
            if (!commonExtensions.isEmpty()) {
                result.indicators.add('Common Salesforce extensions: ' + String.join(commonExtensions, ', '));
            }
        }
    }
    
    /**
     * Checks for non-Salesforce project indicators
     */
    private static void checkNonSalesforceIndicators(List<ZipProcessor.ExtractedFile> files, ProjectDetectionResult result) {
        for (ZipProcessor.ExtractedFile file : files) {
            String fileName = file.name.toLowerCase();
            
            for (String nonSfIndicator : NON_SALESFORCE_INDICATORS) {
                if (fileName.equals(nonSfIndicator.toLowerCase())) {
                    // Check if it's in a tools or scripts directory (acceptable for SF projects)
                    if (!file.path.toLowerCase().contains('/tools/') && 
                        !file.path.toLowerCase().contains('/scripts/') &&
                        !file.path.toLowerCase().contains('/build/')) {
                        result.indicators.add('Found non-Salesforce project file: ' + file.path);
                        result.confidence -= 20;
                    }
                }
            }
        }
    }
    
    /**
     * Determines the final result with stricter confidence thresholds
     */
    private static void determineFinalResult(ProjectDetectionResult result) {
        // Cap confidence at 100 and floor at -100
        result.confidence = Math.min(Math.max(result.confidence, -100), 100);
        
        if (result.confidence >= 80) {
            result.isSalesforceProject = true;
            result.reason = 'High confidence Salesforce project detected with strong indicators';
        } else if (result.confidence >= 60) {
            result.isSalesforceProject = true;
            result.reason = 'Likely Salesforce project based on multiple indicators';
        } else if (result.confidence >= 30) {
            result.isSalesforceProject = false;
            result.reason = 'Uncertain project type - insufficient Salesforce indicators or mixed signals detected';
        } else if (result.confidence >= 0) {
            result.isSalesforceProject = false;
            result.reason = 'Appears to be a non-Salesforce project based on file patterns and structure';
        } else {
            result.isSalesforceProject = false;
            result.reason = 'Strong indicators suggest this is not a Salesforce project (React, Angular, Vue, or other frontend framework detected)';
        }
        
        if (String.isBlank(result.projectType) && result.isSalesforceProject) {
            result.projectType = 'Salesforce Project';
        } else if (!result.isSalesforceProject) {
            // Try to identify what type of project it actually is
            if (result.indicators.toString().contains('React')) {
                result.projectType = 'React Application';
            } else if (result.indicators.toString().contains('Angular')) {
                result.projectType = 'Angular Application';
            } else if (result.indicators.toString().contains('Vue')) {
                result.projectType = 'Vue.js Application';
            } else if (result.indicators.toString().contains('package.json')) {
                result.projectType = 'Node.js Application';
            } else {
                result.projectType = 'Non-Salesforce Project';
            }
        }
    }
    
    /**
     * Checks if a JavaScript file appears to be an LWC component
     */
    private static Boolean isLWCJavaScript(String content) {
        if (String.isBlank(content)) return false;
        
        return content.contains('LightningElement') ||
               content.contains('@wire') ||
               content.contains('import') && content.contains('lwc') ||
               content.contains('lightning/') ||
               content.contains('@api') ||
               content.contains('@track');
    }
    
    /**
     * Quick check method for basic validation
     */
    public static Boolean isSalesforceProject(List<ZipProcessor.ExtractedFile> files) {
        ProjectDetectionResult result = detectSalesforceProject(files);
        return result.isSalesforceProject;
    }
}