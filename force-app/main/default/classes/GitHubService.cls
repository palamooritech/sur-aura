/**
 * Path: force-app/main/default/classes/GitHubService.cls
 * Service class for GitHub API integration and repository processing
 * Updated to handle 302 redirects to S3 buckets
 */
public with sharing class GitHubService {
    
    private static final String GITHUB_API_BASE = 'https://api.github.com';
    private static final Integer TIMEOUT = 120000; // 2 minutes
    
    public class GitHubException extends Exception {}
    
    /**
     * Fetches repository contents as ZIP from GitHub
     * Handles 302 redirects to S3 bucket URLs
     */
    public static Blob fetchRepositoryZip(String repoUrl) {
        try {
            String apiUrl = convertToApiUrl(repoUrl);
            
            // Step 1: Get the redirect URL from GitHub API
            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiUrl);
            req.setMethod('GET');
            req.setTimeout(TIMEOUT);
            req.setHeader('Accept', 'application/vnd.github.v3+json');
            req.setHeader('User-Agent', 'Salesforce-DeprecationScanner/1.0');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Initial response status: ' + res.getStatusCode());
            System.debug('Initial response headers: ' + res.getHeaderKeys());
            
            if (res.getStatusCode() == 302) {
                // Handle redirect - get the Location header
                String redirectUrl = res.getHeader('Location');
                System.debug('Redirect URL: ' + redirectUrl);
                
                if (String.isNotBlank(redirectUrl)) {
                    // Step 2: Follow the redirect to download the actual ZIP
                    return downloadFromRedirectUrl(redirectUrl);
                } else {
                    throw new GitHubException('Received 302 redirect but no Location header found');
                }
            } else if (res.getStatusCode() == 200) {
                // Direct download (unlikely for zipball, but handle it)
                return res.getBodyAsBlob();
            } else if (res.getStatusCode() == 404) {
                throw new GitHubException('Repository not found. Please check the URL and ensure the repository is public.');
            } else if (res.getStatusCode() == 403) {
                throw new GitHubException('Access forbidden. The repository might be private or rate limited.');
            } else {
                throw new GitHubException('Failed to fetch repository: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
            
        } catch (Exception e) {
            if (e instanceof GitHubException) {
                throw e;
            }
            throw new GitHubException('Error fetching repository: ' + e.getMessage());
        }
    }
    
    /**
     * Downloads the ZIP file from the redirected S3 URL
     */
    private static Blob downloadFromRedirectUrl(String redirectUrl) {
        try {
            HttpRequest redirectReq = new HttpRequest();
            redirectReq.setEndpoint(redirectUrl);
            redirectReq.setMethod('GET');
            redirectReq.setTimeout(TIMEOUT);
            // Don't set GitHub-specific headers for S3 download
            
            Http http = new Http();
            HttpResponse redirectRes = http.send(redirectReq);
            
            System.debug('Redirect response status: ' + redirectRes.getStatusCode());
            
            if (redirectRes.getStatusCode() == 200) {
                Blob zipBlob = redirectRes.getBodyAsBlob();
                System.debug('Successfully downloaded ZIP, size: ' + zipBlob.size() + ' bytes');
                return zipBlob;
            } else {
                throw new GitHubException('Failed to download from redirect URL: ' + 
                    redirectRes.getStatusCode() + ' - ' + redirectRes.getStatus());
            }
            
        } catch (Exception e) {
            throw new GitHubException('Error downloading from redirect URL: ' + e.getMessage());
        }
    }
    
    /**
     * Converts GitHub repository URL to API ZIP download URL
     */
    private static String convertToApiUrl(String repoUrl) {
        // Remove .git suffix if present
        repoUrl = repoUrl.endsWith('.git') ? repoUrl.substring(0, repoUrl.length() - 4) : repoUrl;
        
        // Extract owner and repo from URL
        String cleanUrl = repoUrl.replace('https://github.com/', '').replace('http://github.com/', '');
        List<String> parts = cleanUrl.split('/');
        
        if (parts.size() < 2) {
            throw new GitHubException('Invalid GitHub URL format. Expected: https://github.com/owner/repository');
        }
        
        String owner = parts[0];
        String repo = parts[1];
        
        // Return ZIP download URL (defaulting to main branch)
        return GITHUB_API_BASE + '/repos/' + owner + '/' + repo + '/zipball/main';
    }
    
    /**
     * Alternative method that supports different branches
     */
    public static Blob fetchRepositoryZip(String repoUrl, String branch) {
        try {
            String apiUrl = convertToApiUrl(repoUrl, branch);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiUrl);
            req.setMethod('GET');
            req.setTimeout(TIMEOUT);
            req.setHeader('Accept', 'application/vnd.github.v3+json');
            req.setHeader('User-Agent', 'Salesforce-DeprecationScanner/1.0');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 302) {
                String redirectUrl = res.getHeader('Location');
                if (String.isNotBlank(redirectUrl)) {
                    return downloadFromRedirectUrl(redirectUrl);
                } else {
                    throw new GitHubException('Received 302 redirect but no Location header found');
                }
            } else if (res.getStatusCode() == 200) {
                return res.getBodyAsBlob();
            } else if (res.getStatusCode() == 404) {
                throw new GitHubException('Repository or branch not found: ' + branch);
            } else if (res.getStatusCode() == 403) {
                throw new GitHubException('Access forbidden. The repository might be private or rate limited.');
            } else {
                throw new GitHubException('Failed to fetch repository: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
            
        } catch (Exception e) {
            if (e instanceof GitHubException) {
                throw e;
            }
            throw new GitHubException('Error fetching repository: ' + e.getMessage());
        }
    }
    
    /**
     * Converts GitHub repository URL to API ZIP download URL with branch
     */
    private static String convertToApiUrl(String repoUrl, String branch) {
        repoUrl = repoUrl.endsWith('.git') ? repoUrl.substring(0, repoUrl.length() - 4) : repoUrl;
        
        String cleanUrl = repoUrl.replace('https://github.com/', '').replace('http://github.com/', '');
        List<String> parts = cleanUrl.split('/');
        
        if (parts.size() < 2) {
            throw new GitHubException('Invalid GitHub URL format. Expected: https://github.com/owner/repository');
        }
        
        String owner = parts[0];
        String repo = parts[1];
        
        return GITHUB_API_BASE + '/repos/' + owner + '/' + repo + '/zipball/' + branch;
    }
    
    /**
     * Validates if the URL is a valid GitHub repository URL
     */
    public static Boolean isValidGitHubUrl(String url) {
        if (String.isBlank(url)) {
            return false;
        }
        
        // Regex: matches https://github.com/owner/repo
        String patternString = '^https?://(www\\.)?github\\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+/?$';
        
        System.Pattern p = System.Pattern.compile(patternString);
        System.Matcher m = p.matcher(url.trim());
        return m.matches();
    }
    
    /**
     * Extracts repository information from URL
     */
    public static Map<String, String> extractRepoInfo(String repoUrl) {
        Map<String, String> repoInfo = new Map<String, String>();
        
        try {
            String cleanUrl = repoUrl.replace('https://github.com/', '').replace('http://github.com/', '');
            if (cleanUrl.endsWith('.git')) {
                cleanUrl = cleanUrl.substring(0, cleanUrl.length() - 4);
            }
            
            List<String> parts = cleanUrl.split('/');
            if (parts.size() >= 2) {
                repoInfo.put('owner', parts[0]);
                repoInfo.put('name', parts[1]);
                repoInfo.put('fullName', parts[0] + '/' + parts[1]);
            }
        } catch (Exception e) {
            System.debug('Error extracting repo info: ' + e.getMessage());
        }
        
        return repoInfo;
    }
}