/**
 * Path: force-app/main/default/classes/DeprecationRule.cls
 * Represents a deprecation rule for pattern matching and replacement suggestions
 */
public class DeprecationRule {
    
    public enum ComponentType {
        AURA, LWC, APEX
    }
    
    public enum RuleType {
        EXACT_MATCH, PATTERN_MATCH, IMPORT_STATEMENT
    }
    
    public String id { get; set; }
    public String name { get; set; }
    public ComponentType componentType { get; set; }
    public RuleType ruleType { get; set; }
    public String deprecatedPattern { get; set; }
    public String replacement { get; set; }
    public String description { get; set; }
    public String documentationUrl { get; set; }
    public String severity { get; set; } // HIGH, MEDIUM, LOW
    public Boolean isRegex { get; set; }
    
    public DeprecationRule() {
        this.isRegex = false;
        this.severity = 'MEDIUM';
    }
    
    public DeprecationRule(String name, ComponentType componentType, String deprecatedPattern, String replacement) {
        this();
        this.name = name;
        this.componentType = componentType;
        this.deprecatedPattern = deprecatedPattern;
        this.replacement = replacement;
        this.id = generateId(name, deprecatedPattern);
    }
    
    private String generateId(String name, String pattern) {
        return (name + pattern).replaceAll('[^a-zA-Z0-9]', '').toLowerCase();
    }
    
    /**
     * Factory method to create built-in deprecation rules
     */
    public static List<DeprecationRule> getBuiltInRules() {
        List<DeprecationRule> rules = new List<DeprecationRule>();
        
        // LWC Rules
        rules.addAll(getLWCRules());
        
        // Aura Rules  
        rules.addAll(getAuraRules());
        
        // Apex Rules
        rules.addAll(getApexRules());
        
        return rules;
    }
    
    private static List<DeprecationRule> getLWCRules() {
        List<DeprecationRule> lwcRules = new List<DeprecationRule>();
        
        // getListUi deprecation
        DeprecationRule getListUiRule = new DeprecationRule(
            'getListUi Wire Adapter',
            ComponentType.LWC,
            'getListUi',
            'getListInfoByName'
        );
        getListUiRule.ruleType = RuleType.IMPORT_STATEMENT;
        getListUiRule.description = 'getListUi is deprecated. Use getListInfoByName wire adapter instead.';
        getListUiRule.documentationUrl = 'https://developer.salesforce.com/docs/platform/lwc/guide/reference-get-list-ui.html';
        getListUiRule.severity = 'HIGH';
        lwcRules.add(getListUiRule);
        
        // lightning/uiListApi module
        DeprecationRule uiListApiRule = new DeprecationRule(
            'uiListApi Module',
            ComponentType.LWC,
            'lightning/uiListApi',
            'lightning/uiListsApi'
        );
        uiListApiRule.ruleType = RuleType.IMPORT_STATEMENT;
        uiListApiRule.description = 'lightning/uiListApi module is deprecated. Use lightning/uiListsApi instead.';
        uiListApiRule.severity = 'HIGH';
        lwcRules.add(uiListApiRule);
        
        // getRecordUi deprecation
        DeprecationRule getRecordUiRule = new DeprecationRule(
            'getRecordUi Wire Adapter',
            ComponentType.LWC,
            'getRecordUi',
            'getLayout'
        );
        getRecordUiRule.ruleType = RuleType.IMPORT_STATEMENT;
        getRecordUiRule.description = 'getRecordUi is deprecated. Use getLayout wire adapter instead.';
        getRecordUiRule.documentationUrl = 'https://developer.salesforce.com/docs/platform/lwc/guide/reference-wire-adapters-record-ui.html';
        getRecordUiRule.severity = 'HIGH';
        lwcRules.add(getRecordUiRule);
        
        // registerApexTestWireAdapter
        DeprecationRule testAdapterRule = new DeprecationRule(
            'registerApexTestWireAdapter',
            ComponentType.LWC,
            'registerApexTestWireAdapter',
            'createApexTestWireAdapter'
        );
        testAdapterRule.ruleType = RuleType.EXACT_MATCH;
        testAdapterRule.description = 'registerApexTestWireAdapter is deprecated in LWC Jest test suite.';
        testAdapterRule.severity = 'MEDIUM';
        lwcRules.add(testAdapterRule);
        
        return lwcRules;
    }
    
    private static List<DeprecationRule> getAuraRules() {
        List<DeprecationRule> auraRules = new List<DeprecationRule>();
        
        // UI namespace components
        Map<String, String> uiComponentMappings = new Map<String, String>{
            'ui:button' => 'lightning-button',
            'ui:inputText' => 'lightning-input (type="text")',
            'ui:inputEmail' => 'lightning-input (type="email")',
            'ui:inputNumber' => 'lightning-input (type="number")',
            'ui:inputCheckbox' => 'lightning-input (type="checkbox")',
            'ui:inputDate' => 'lightning-input (type="date")',
            'ui:inputDateTime' => 'lightning-input (type="datetime")',
            'ui:inputTextArea' => 'lightning-textarea',
            'ui:inputSelect' => 'lightning-combobox or lightning-select',
            'ui:inputPhone' => 'lightning-input (type="phone")',
            'ui:inputURL' => 'lightning-input (type="url")',
            'ui:inputCurrency' => 'lightning-input (type="number") with currency formatting',
            'ui:inputSecret' => 'lightning-input (type="password")',
            'ui:inputRadio' => 'lightning-radio-group',
            'ui:inputRichText' => 'lightning-input-rich-text',
            'ui:outputText' => 'lightning-formatted-text',
            'ui:outputEmail' => 'lightning-formatted-email',
            'ui:outputPhone' => 'lightning-formatted-phone',
            'ui:outputURL' => 'lightning-formatted-url or <a> tags',
            'ui:outputNumber' => 'lightning-formatted-number',
            'ui:outputCurrency' => 'lightning-formatted-number (style="currency")',
            'ui:outputDate' => 'lightning-formatted-date-time',
            'ui:outputDateTime' => 'lightning-formatted-date-time',
            'ui:outputRichText' => 'lightning-formatted-rich-text',
            'ui:spinner' => 'lightning-spinner',
            'ui:message' => 'lightning/platformShowToastEvent'
        };
        
        for (String deprecated : uiComponentMappings.keySet()) {
            DeprecationRule rule = new DeprecationRule(
                deprecated,
                ComponentType.AURA,
                deprecated,
                uiComponentMappings.get(deprecated)
            );
            rule.ruleType = RuleType.EXACT_MATCH;
            rule.description = deprecated + ' is deprecated. Support ended May 1, 2021.';
            rule.documentationUrl = 'https://developer.salesforce.com/docs/platform/lwc/guide/migrate-map-ui-components.html';
            rule.severity = 'HIGH';
            auraRules.add(rule);
        }
        
        return auraRules;
    }
    
    private static List<DeprecationRule> getApexRules() {
        List<DeprecationRule> apexRules = new List<DeprecationRule>();
        
        // Add common Apex deprecations here as they are discovered
        // This can be expanded based on Salesforce release notes
        
        return apexRules;
    }
}