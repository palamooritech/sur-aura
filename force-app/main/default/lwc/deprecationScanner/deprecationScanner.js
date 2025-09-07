/**
 * Path: force-app/main/default/lwc/deprecationScanner/deprecationScanner.js
 * LWC component for scanning GitHub repositories for deprecated Salesforce components
 */
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import scanGitHubRepository from '@salesforce/apex/DeprecationScannerController.scanGitHubRepository';
import validateGitHubUrl from '@salesforce/apex/DeprecationScannerController.validateGitHubUrl';
import getRepositoryInfo from '@salesforce/apex/DeprecationScannerController.getRepositoryInfo';
import getScanStatistics from '@salesforce/apex/DeprecationScannerController.getScanStatistics';
import quickScanCheck from '@salesforce/apex/DeprecationScannerController.quickScanCheck';

export default class DeprecationScanner extends LightningElement {
    
    // Form data
    @track repositoryUrl = '';
    @track isScanning = false;
    @track hasResults = false;
    
    // Scan results
    @track scanResult = null;
    @track findings = [];
    @track scanSummary = '';
    
    // UI state
    @track activeTab = 'scan';
    @track showDetails = false;
    @track selectedFinding = null;
    
    // Statistics
    @track statistics = {};
    
    // Validation
    @track urlValidation = {
        isValid: true,
        message: ''
    };
    
    // Wire statistics on component load
    @wire(getScanStatistics)
    wiredStatistics({ error, data }) {
        if (data) {
            this.statistics = data;
        } else if (error) {
            console.error('Error loading statistics:', error);
        }
    }
    
    // Computed properties
    get isUrlValid() {
        return this.urlValidation.isValid && this.repositoryUrl.trim().length > 0;
    }
    
    get canScan() {
        return this.isUrlValid && !this.isScanning;
    }
    
    get scanButtonLabel() {
        return this.isScanning ? 'Scanning...' : 'Scan Repository';
    }
    
    get findingsCount() {
        return this.findings ? this.findings.length : 0;
    }
    
    get hasFindings() {
        return this.findingsCount > 0;
    }
    
    get severityVariant() {
        if (!this.scanResult) return 'base';
        
        const highPriorityFindings = this.findings.filter(f => f.severity === 'HIGH');
        if (highPriorityFindings.length > 0) return 'error';
        
        const mediumPriorityFindings = this.findings.filter(f => f.severity === 'MEDIUM');
        if (mediumPriorityFindings.length > 0) return 'warning';
        
        return 'success';
    }
    
    get tabOptions() {
        return [
            { label: 'Scan Repository', value: 'scan' },
            { label: 'Results', value: 'results', disabled: !this.hasResults },
            { label: 'Statistics', value: 'statistics' }
        ];
    }

    // ✅ Added computed getters for validation display
    get containerClass() {
        return this.urlValidation.isValid
            ? 'slds-text-color_success'
            : 'slds-text-color_error';
    }

    get iconName() {
        return this.urlValidation.isValid
            ? 'utility:success'
            : 'utility:error';
    }
    
    // Event handlers
    handleUrlChange(event) {
        this.repositoryUrl = event.target.value;
        this.validateUrl();
    }
    
    handleTabChange(event) {
        this.activeTab = event.target.value;
    }
    
    async validateUrl() {
        const url = this.repositoryUrl.trim();
        
        if (!url) {
            this.urlValidation = { isValid: true, message: '' };
            return;
        }
        
        try {
            const isValid = await validateGitHubUrl({ repositoryUrl: url });
            
            if (isValid) {
                this.urlValidation = { 
                    isValid: true, 
                    message: 'Valid GitHub repository URL' 
                };
                
                // Get repository info for preview
                const repoInfo = await getRepositoryInfo({ repositoryUrl: url });
                if (repoInfo && repoInfo.fullName) {
                    this.urlValidation.message = `Repository: ${repoInfo.fullName}`;
                }
            } else {
                this.urlValidation = { 
                    isValid: false, 
                    message: 'Invalid GitHub repository URL format' 
                };
            }
        } catch (error) {
            this.urlValidation = { 
                isValid: false, 
                message: 'Error validating URL: ' + (error.body?.message || error.message) 
            };
        }
    }
    
    async handleScan() {
        if (!this.canScan) return;
        
        this.isScanning = true;
        this.hasResults = false;
        this.scanResult = null;
        this.findings = [];
        
        try {
            // Show initial toast
            this.showToast('Info', 'Starting repository scan...', 'info');
            
            // Perform the scan
            const result = await scanGitHubRepository({ repositoryUrl: this.repositoryUrl.trim() });
            
            this.processScanResult(result);
            
        } catch (error) {
            console.error('Scan error:', error);
            this.showToast(
                'Error', 
                'Failed to scan repository: ' + (error.body?.message || error.message), 
                'error'
            );
        } finally {
            this.isScanning = false;
        }
    }
    
    processScanResult(result) {
        this.scanResult = result;
        this.findings = result.findings || [];
        this.scanSummary = result.summary || '';
        this.hasResults = true;
        
        // Switch to results tab
        this.activeTab = 'results';
        
        // Show completion toast
        if (result.status === 'SUCCESS') {
            if (this.hasFindings) {
                this.showToast(
                    'Scan Complete', 
                    `Found ${this.findingsCount} deprecated component(s)`, 
                    'warning'
                );
            } else {
                this.showToast(
                    'Scan Complete', 
                    'No deprecated components found!', 
                    'success'
                );
            }
        } else {
            this.showToast(
                'Scan Completed with Errors', 
                result.errors?.join('; ') || 'Unknown error occurred', 
                'error'
            );
        }
    }
    
    handleFindingClick(event) {
        const findingIndex = parseInt(event.currentTarget.dataset.index);
        this.selectedFinding = this.findings[findingIndex];
        this.showDetails = true;
    }
    
    handleCloseDetails() {
        this.showDetails = false;
        this.selectedFinding = null;
    }
    
    handleNewScan() {
        this.repositoryUrl = '';
        this.hasResults = false;
        this.scanResult = null;
        this.findings = [];
        this.activeTab = 'scan';
        this.urlValidation = { isValid: true, message: '' };
    }
    
    handleExportResults() {
        if (!this.scanResult) return;
        
        try {
            const exportData = {
                repository: this.scanResult.repositoryName,
                scanDate: this.scanResult.scanTimestamp,
                summary: this.scanSummary,
                findings: this.findings.map(finding => ({
                    file: finding.filePath,
                    line: finding.lineNumber,
                    deprecated: finding.deprecatedComponent,
                    replacement: finding.recommendedReplacement,
                    severity: finding.severity,
                    description: finding.description
                }))
            };
            
            const dataStr = JSON.stringify(exportData, null, 2);
            const dataBlob = new Blob([dataStr], { type: 'application/json' });
            
            // Create download link
            const link = document.createElement('a');
            link.href = URL.createObjectURL(dataBlob);
            link.download = `deprecation-scan-${this.scanResult.repositoryName?.replace('/', '-') || 'results'}.json`;
            link.click();
            
            this.showToast('Success', 'Results exported successfully', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to export results: ' + error.message, 'error');
        }
    }
    
    // Utility methods
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
    
    getSeverityClass(severity) {
        switch (severity) {
            case 'HIGH':
                return 'slds-text-color_error';
            case 'MEDIUM':
                return 'slds-text-color_warning';
            case 'LOW':
                return 'slds-text-color_success';
            default:
                return '';
        }
    }
    
    getSeverityIcon(severity) {
        switch (severity) {
            case 'HIGH':
                return 'utility:error';
            case 'MEDIUM':
                return 'utility:warning';
            case 'LOW':
                return 'utility:info';
            default:
                return 'utility:info';
        }
    }
    
    getSeverityIconForFinding(finding) {
        return this.getSeverityIcon(finding.severity);
    }
    
    getSeverityClassForFinding(finding) {
        return this.getSeverityClass(finding.severity);
    }
    
    formatDate(dateString) {
        if (!dateString) return '';
        return new Date(dateString).toLocaleString();
    }

    get alertClass() {
        return `slds-notify slds-notify_alert slds-theme_${this.severityVariant} slds-m-bottom_medium`;
    }

    get isResultsDisabled() {
        return !this.hasResults;
    }

    get isScanDisabled() {
        return !this.canScan;
    }

}
