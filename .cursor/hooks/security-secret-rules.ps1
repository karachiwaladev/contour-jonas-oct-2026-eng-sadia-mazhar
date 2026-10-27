function Get-SecuritySecretRules {
  @(
    @{ Name = 'private-key-header'; Pattern = '-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' },
    @{ Name = 'github-token'; Pattern = '\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b' },
    @{ Name = 'aws-access-key'; Pattern = '\b(?:AKIA|ASIA)[A-Z0-9]{16}\b' },
    @{ Name = 'assigned-secret'; Pattern = '(?i)\b(?:api[_-]?key|client[_-]?secret|access[_-]?token|password)\b\s*[:=]\s*["''][A-Za-z0-9+/_.=-]{16,}["'']' }
  )
}
