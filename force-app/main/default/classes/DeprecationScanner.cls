/**
 * Path: force-app/main/default/classes/DeprecationScanner.cls
 * Core scanning engine for detecting deprecated Salesforce components
 * Updated with Salesforce project detection
 */
public with sharing class DeprecationScanner {
    
    private List<DeprecationRule> rules;
    private static DeprecationScanner instance;
    
    public class ScannerException extends Exception {}
    
    /**
     * Singleton pattern for scanner instance
     */
    public static DeprecationScanner getInstance() {
        if (instance == null) {
            instance = new DeprecationScanner();
        }
        return instance;
    }
    
    private DeprecationScanner() {
        this.rules = DeprecationRule.getBuiltInRules();
    }
    
    /**
     * Main scanning method - scans a repository and returns results
     */
    public ScanResult scanRepository(String repositoryUrl) {
        ScanResult result = new ScanResult(repositoryUrl);
        
        try {
            // Extract repository information
            Map<String, String> repoInfo = GitHubService.extractRepoInfo(repositoryUrl);
            result.repositoryName = repoInfo.get('fullName');
            
            // Validate GitHub URL
            if (!GitHubService.isValidGitHubUrl(repositoryUrl)) {
                result.addError('Invalid GitHub repository URL');
                return result;
            }
            
            // Fetch repository ZIP
            Blob zipContent = GitHubService.fetchRepositoryZip(repositoryUrl);
            
            // Extract files from ZIP
            List<ZipProcessor.ExtractedFile> extractedFiles = ZipProcessor.extractScannableFiles(zipContent);
            
            // **NEW: Check if this is a Salesforce project**
            SalesforceProjectDetector.ProjectDetectionResult projectDetection = 
                SalesforceProjectDetector.detectSalesforceProject(extractedFiles);
            
            if (!projectDetection.isSalesforceProject) {
                result.addError('This repository does not appear to be a Salesforce project. ' + 
                               projectDetection.reason);
                
                // Add detection details for debugging
                if (!projectDetection.indicators.isEmpty()) {
                    result.addError('Detection details: ' + String.join(projectDetection.indicators, '; '));
                }
                
                result.status = 'ERROR';
                return result;
            }
            
            // Log successful project detection
            System.debug('Salesforce project detected: ' + projectDetection.projectType + 
                        ' (Confidence: ' + projectDetection.confidence + '%)');
            
            result.totalFilesScanned = extractedFiles.size();
            
            // Scan each file for deprecations
            for (ZipProcessor.ExtractedFile file : extractedFiles) {
                List<ScanResult.DeprecationFinding> fileFindings = scanFile(file);
                for (ScanResult.DeprecationFinding finding : fileFindings) {
                    result.addFinding(finding);
                }
            }
            
            // Generate summary with project type info
            result.generateSummary();
            if (result.totalDeprecationsFound == 0) {
                result.summary = 'Scanned ' + projectDetection.projectType + '. ' + result.summary;
            } else {
                result.summary = 'Scanned ' + projectDetection.projectType + ' and found issues. ' + result.summary;
            }
            
        } catch (GitHubService.GitHubException e) {
            result.addError('GitHub Error: ' + e.getMessage());
        } catch (ZipProcessor.ZipProcessorException e) {
            result.addError('ZIP Processing Error: ' + e.getMessage());
        } catch (Exception e) {
            result.addError('Unexpected Error: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * NEW: Quick validation method to check if repository is a Salesforce project
     */
    public ScanResult validateSalesforceProject(String repositoryUrl) {
        ScanResult result = new ScanResult(repositoryUrl);
        
        try {
            // Extract repository information
            Map<String, String> repoInfo = GitHubService.extractRepoInfo(repositoryUrl);
            result.repositoryName = repoInfo.get('fullName');
            
            // Validate GitHub URL
            if (!GitHubService.isValidGitHubUrl(repositoryUrl)) {
                result.addError('Invalid GitHub repository URL');
                return result;
            }
            
            // Fetch repository ZIP
            Blob zipContent = GitHubService.fetchRepositoryZip(repositoryUrl);
            
            // Extract files from ZIP
            List<ZipProcessor.ExtractedFile> extractedFiles = ZipProcessor.extractScannableFiles(zipContent);
            
            // Check if this is a Salesforce project
            SalesforceProjectDetector.ProjectDetectionResult projectDetection = 
                SalesforceProjectDetector.detectSalesforceProject(extractedFiles);
            
            if (projectDetection.isSalesforceProject) {
                result.summary = 'Validated as ' + projectDetection.projectType + 
                               ' (Confidence: ' + projectDetection.confidence + '%)';
                result.status = 'SUCCESS';
            } else {
                result.addError('Not a Salesforce project: ' + projectDetection.reason);
                if (!projectDetection.indicators.isEmpty()) {
                    result.addError('Analysis: ' + String.join(projectDetection.indicators, '; '));
                }
                result.status = 'ERROR';
            }
            
            result.totalFilesScanned = extractedFiles.size();
            
        } catch (Exception e) {
            result.addError('Validation Error: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Scans a single file for deprecation patterns
     */
    private List<ScanResult.DeprecationFinding> scanFile(ZipProcessor.ExtractedFile file) {
        List<ScanResult.DeprecationFinding> findings = new List<ScanResult.DeprecationFinding>();
        
        try {
            // Determine file type and apply appropriate rules
            DeprecationRule.ComponentType fileType = determineFileType(file);
            
            // Get applicable rules for this file type
            List<DeprecationRule> applicableRules = getApplicableRules(fileType);
            
            // Scan file content against each rule
            for (DeprecationRule rule : applicableRules) {
                List<ScanResult.DeprecationFinding> ruleFindings = applyRule(file, rule);
                findings.addAll(ruleFindings);
            }
            
        } catch (Exception e) {
            System.debug('Error scanning file ' + file.path + ': ' + e.getMessage());
        }
        
        return findings;
    }
    
    /**
     * Determines the component type based on file extension and path
     */
    private DeprecationRule.ComponentType determineFileType(ZipProcessor.ExtractedFile file) {
        String extension = file.extension.toLowerCase();
        String path = file.path.toLowerCase();
        
        // LWC files
        if (extension == 'js' && path.contains('/lwc/')) {
            return DeprecationRule.ComponentType.LWC;
        }
        
        // Aura files
        if ((extension == 'cmp' || extension == 'app' || extension == 'evt' || extension == 'intf') && 
            path.contains('/aura/')) {
            return DeprecationRule.ComponentType.AURA;
        }
        
        // Apex files
        if (extension == 'cls' || extension == 'trigger') {
            return DeprecationRule.ComponentType.APEX;
        }
        
        // Default to LWC for JavaScript files
        if (extension == 'js') {
            return DeprecationRule.ComponentType.LWC;
        }
        
        // Default to Aura for markup files
        if (extension == 'html' || extension == 'cmp') {
            return DeprecationRule.ComponentType.AURA;
        }
        
        return DeprecationRule.ComponentType.LWC; // Default
    }
    
    /**
     * Gets rules applicable to a specific component type
     */
    private List<DeprecationRule> getApplicableRules(DeprecationRule.ComponentType componentType) {
        List<DeprecationRule> applicableRules = new List<DeprecationRule>();
        
        for (DeprecationRule rule : this.rules) {
            if (rule.componentType == componentType) {
                applicableRules.add(rule);
            }
        }
        
        return applicableRules;
    }
    
    /**
     * Applies a single rule to a file and returns findings
     */
    private List<ScanResult.DeprecationFinding> applyRule(ZipProcessor.ExtractedFile file, DeprecationRule rule) {
        List<ScanResult.DeprecationFinding> findings = new List<ScanResult.DeprecationFinding>();
        
        if (String.isBlank(file.content)) {
            return findings;
        }
        
        try {
            switch on rule.ruleType {
                when EXACT_MATCH {
                    findings.addAll(findExactMatches(file, rule));
                }
                when PATTERN_MATCH {
                    findings.addAll(findPatternMatches(file, rule));
                }
                when IMPORT_STATEMENT {
                    findings.addAll(findImportStatements(file, rule));
                }
            }
        } catch (Exception e) {
            System.debug('Error applying rule ' + rule.name + ' to file ' + file.path + ': ' + e.getMessage());
        }
        
        return findings;
    }
    
    /**
     * Finds exact string matches in file content
     */
    private List<ScanResult.DeprecationFinding> findExactMatches(ZipProcessor.ExtractedFile file, DeprecationRule rule) {
        List<ScanResult.DeprecationFinding> findings = new List<ScanResult.DeprecationFinding>();
        
        if (file.content.contains(rule.deprecatedPattern)) {
            ScanResult.DeprecationFinding finding = new ScanResult.DeprecationFinding(file.path, rule.deprecatedPattern, rule);
            finding.lineNumber = findLineNumber(file.content, rule.deprecatedPattern);
            finding.codeSnippet = extractCodeSnippet(file.content, finding.lineNumber);
            findings.add(finding);
        }
        
        return findings;
    }
    
    /**
     * Finds pattern matches using regex (if rule is marked as regex)
     */
    private List<ScanResult.DeprecationFinding> findPatternMatches(ZipProcessor.ExtractedFile file, DeprecationRule rule) {
        List<ScanResult.DeprecationFinding> findings = new List<ScanResult.DeprecationFinding>();
        
        if (rule.isRegex) {
            // Use System.Pattern class for regex matching
            System.Pattern p = System.Pattern.compile(rule.deprecatedPattern);
            System.Matcher m = p.matcher(file.content);
            
            while (m.find()) {
                ScanResult.DeprecationFinding finding = new ScanResult.DeprecationFinding(file.path, m.group(), rule);
                finding.lineNumber = findLineNumber(file.content, m.group());
                finding.codeSnippet = extractCodeSnippet(file.content, finding.lineNumber);
                findings.add(finding);
            }
        } else {
            // Fall back to exact match
            findings.addAll(findExactMatches(file, rule));
        }
        
        return findings;
    }
    
    /**
     * Finds import statements in JavaScript/LWC files
     */
    private List<ScanResult.DeprecationFinding> findImportStatements(ZipProcessor.ExtractedFile file, DeprecationRule rule) {
        List<ScanResult.DeprecationFinding> findings = new List<ScanResult.DeprecationFinding>();
        
        // Look for import statements containing the deprecated pattern
        List<String> lines = file.content.split('\n');
        for (Integer i = 0; i < lines.size(); i++) {
            String line = lines[i].trim();
            if (line.startsWith('import') && line.contains(rule.deprecatedPattern)) {
                ScanResult.DeprecationFinding finding = new ScanResult.DeprecationFinding(file.path, rule.deprecatedPattern, rule);
                finding.lineNumber = i + 1;
                finding.codeSnippet = line;
                findings.add(finding);
            }
        }
        
        return findings;
    }
    
    /**
     * Finds the line number where a pattern occurs
     */
    private Integer findLineNumber(String content, String pattern) {
        List<String> lines = content.split('\n');
        for (Integer i = 0; i < lines.size(); i++) {
            if (lines[i].contains(pattern)) {
                return i + 1; // Line numbers start at 1
            }
        }
        return 1;
    }
    
    /**
     * Extracts a code snippet around the specified line number
     */
    private String extractCodeSnippet(String content, Integer lineNumber) {
        List<String> lines = content.split('\n');
        
        if (lineNumber == null || lineNumber < 1 || lineNumber > lines.size()) {
            return '';
        }
        
        Integer startLine = Math.max(0, lineNumber - 2); // Show 1 line before
        Integer endLine = Math.min(lines.size() - 1, lineNumber + 1); // Show 1 line after
        
        List<String> snippetLines = new List<String>();
        for (Integer i = startLine; i <= endLine; i++) {
            String prefix = (i == lineNumber - 1) ? '> ' : '  ';
            snippetLines.add(prefix + (i + 1) + ': ' + lines[i]);
        }
        
        return String.join(snippetLines, '\n');
    }
    
    /**
     * Adds custom rules to the scanner
     */
    public void addCustomRule(DeprecationRule rule) {
        if (this.rules == null) {
            this.rules = new List<DeprecationRule>();
        }
        this.rules.add(rule);
    }
    
    /**
     * Gets all loaded rules
     */
    public List<DeprecationRule> getRules() {
        return this.rules;
    }
    
    /**
     * NEW: Analyzes downloaded files to verify correct repository was fetched
     */
    private Map<String, Object> analyzeDownloadedFiles(List<ZipProcessor.ExtractedFile> files, String expectedRepoName) {
        Map<String, Object> analysis = new Map<String, Object>();
        List<String> warnings = new List<String>();
        
        if (files.isEmpty()) {
            warnings.add('No files were extracted from the repository');
            analysis.put('warnings', warnings);
            return analysis;
        }
        
        // Analyze file paths to determine repository structure
        Set<String> topLevelDirectories = new Set<String>();
        String detectedRepoName = '';
        List<String> sampleFilePaths = new List<String>();
        
        for (ZipProcessor.ExtractedFile file : files) {
            // Collect sample file paths (first 10)
            if (sampleFilePaths.size() < 10) {
                sampleFilePaths.add(file.path);
            }
            
            // Extract top-level directory (often contains repo name)
            String[] pathParts = file.path.split('/');
            if (pathParts.size() > 0 && !String.isBlank(pathParts[0])) {
                topLevelDirectories.add(pathParts[0]);
                
                // GitHub typically prefixes with reponame-branchname
                if (String.isBlank(detectedRepoName)) {
                    detectedRepoName = pathParts[0];
                }
            }
        }
        
        // Verify repository name matching
        if (String.isNotBlank(expectedRepoName) && String.isNotBlank(detectedRepoName)) {
            String expectedRepo = expectedRepoName.contains('/') ? expectedRepoName.split('/')[1] : expectedRepoName;
            
            if (!detectedRepoName.toLowerCase().contains(expectedRepo.toLowerCase())) {
                warnings.add('Repository name mismatch! Expected: ' + expectedRepo + 
                           ', but downloaded files suggest: ' + detectedRepoName);
            }
        }
        
        // Check for suspicious patterns
        if (topLevelDirectories.size() > 5) {
            warnings.add('Unusual repository structure - multiple top-level directories detected: ' + 
                        String.join(new List<String>(topLevelDirectories), ', '));
        }
        
        // Store analysis results
        analysis.put('repositoryName', detectedRepoName);
        analysis.put('topDirectories', String.join(new List<String>(topLevelDirectories), ', '));
        analysis.put('samplePaths', sampleFilePaths);
        
        if (!warnings.isEmpty()) {
            analysis.put('warnings', warnings);
        }
        
        // Debug logging
        System.debug('=== FILE ANALYSIS ===');
        System.debug('Detected repo name: ' + detectedRepoName);
        System.debug('Expected repo name: ' + expectedRepoName);
        System.debug('Top directories: ' + analysis.get('topDirectories'));
        System.debug('Sample file paths: ' + String.join(sampleFilePaths, ', '));
        System.debug('===================');
        
        return analysis;
    }
    
    /**
     * Performs a quick scan to check if file contains any deprecated patterns
     */
    public Boolean hasDeprecatedComponents(String fileContent, DeprecationRule.ComponentType componentType) {
        List<DeprecationRule> applicableRules = getApplicableRules(componentType);
        
        for (DeprecationRule rule : applicableRules) {
            if (fileContent.contains(rule.deprecatedPattern)) {
                return true;
            }
        }
        
        return false;
    }
}