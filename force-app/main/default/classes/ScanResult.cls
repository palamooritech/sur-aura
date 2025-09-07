/**
 * Path: force-app/main/default/classes/ScanResult.cls
 * Represents the result of a deprecation scan
 */
public class ScanResult {
    
    @AuraEnabled
    public String id { get; set; }
    
    @AuraEnabled
    public String repositoryUrl { get; set; }
    
    @AuraEnabled
    public String repositoryName { get; set; }
    
    @AuraEnabled
    public DateTime scanTimestamp { get; set; }
    
    @AuraEnabled
    public Integer totalFilesScanned { get; set; }
    
    @AuraEnabled
    public Integer totalDeprecationsFound { get; set; }
    
    @AuraEnabled
    public List<DeprecationFinding> findings { get; set; }
    
    @AuraEnabled
    public List<String> errors { get; set; }
    
    @AuraEnabled
    public String status { get; set; } // SUCCESS, ERROR, PARTIAL
    
    @AuraEnabled
    public String summary { get; set; }
    
    public ScanResult() {
        this.findings = new List<DeprecationFinding>();
        this.errors = new List<String>();
        this.scanTimestamp = DateTime.now();
        this.status = 'SUCCESS';
        this.totalFilesScanned = 0;
        this.totalDeprecationsFound = 0;
    }
    
    public ScanResult(String repositoryUrl) {
        this();
        this.repositoryUrl = repositoryUrl;
        this.id = generateScanId();
    }
    
    private String generateScanId() {
        return 'SCAN_' + DateTime.now().getTime() + '_' + Math.round(Math.random() * 1000);
    }
    
    public void addFinding(DeprecationFinding finding) {
        if (this.findings == null) {
            this.findings = new List<DeprecationFinding>();
        }
        this.findings.add(finding);
        this.totalDeprecationsFound = this.findings.size();
    }
    
    public void addError(String errorMessage) {
        if (this.errors == null) {
            this.errors = new List<String>();
        }
        this.errors.add(errorMessage);
        if (!this.errors.isEmpty()) {
            this.status = 'ERROR';
        }
    }
    
    public void generateSummary() {
        if (this.totalDeprecationsFound == 0) {
            this.summary = 'Great news! No deprecated components found in this repository.';
        } else {
            Map<String, Integer> severityCounts = new Map<String, Integer>{
                'HIGH' => 0,
                'MEDIUM' => 0,
                'LOW' => 0
            };
            
            Map<String, Integer> typeCounts = new Map<String, Integer>{
                'AURA' => 0,
                'LWC' => 0,
                'APEX' => 0
            };
            
            for (DeprecationFinding finding : this.findings) {
                if (severityCounts.containsKey(finding.severity)) {
                    severityCounts.put(finding.severity, severityCounts.get(finding.severity) + 1);
                }
                if (typeCounts.containsKey(finding.componentType)) {
                    typeCounts.put(finding.componentType, typeCounts.get(finding.componentType) + 1);
                }
            }
            
            List<String> summaryParts = new List<String>();
            summaryParts.add('Found ' + this.totalDeprecationsFound + ' deprecated component(s) in ' + this.totalFilesScanned + ' files.');
            
            if (severityCounts.get('HIGH') > 0) {
                summaryParts.add(severityCounts.get('HIGH') + ' high priority issues require immediate attention.');
            }
            
            if (typeCounts.get('AURA') > 0) {
                summaryParts.add(typeCounts.get('AURA') + ' Aura component issues found.');
            }
            
            if (typeCounts.get('LWC') > 0) {
                summaryParts.add(typeCounts.get('LWC') + ' LWC component issues found.');
            }
            
            this.summary = String.join(summaryParts, ' ');
        }
    }
    
    /**
     * Inner class representing a single deprecation finding
     */
    public class DeprecationFinding {
        @AuraEnabled
        public String filePath { get; set; }
        
        @AuraEnabled
        public String fileName { get; set; }
        
        @AuraEnabled
        public Integer lineNumber { get; set; }
        
        @AuraEnabled
        public String deprecatedComponent { get; set; }
        
        @AuraEnabled
        public String recommendedReplacement { get; set; }
        
        @AuraEnabled
        public String description { get; set; }
        
        @AuraEnabled
        public String documentationUrl { get; set; }
        
        @AuraEnabled
        public String severity { get; set; }
        
        @AuraEnabled
        public String componentType { get; set; }
        
        @AuraEnabled
        public String codeSnippet { get; set; }
        
        public DeprecationFinding() {}
        
        public DeprecationFinding(String filePath, String deprecatedComponent, DeprecationRule rule) {
            this.filePath = filePath;
            this.fileName = extractFileName(filePath);
            this.deprecatedComponent = deprecatedComponent;
            this.recommendedReplacement = rule.replacement;
            this.description = rule.description;
            this.documentationUrl = rule.documentationUrl;
            this.severity = rule.severity;
            this.componentType = String.valueOf(rule.componentType);
        }
        
        private String extractFileName(String filePath) {
            if (String.isBlank(filePath)) return '';
            List<String> pathParts = filePath.split('/');
            return pathParts.isEmpty() ? filePath : pathParts[pathParts.size() - 1];
        }
    }
}