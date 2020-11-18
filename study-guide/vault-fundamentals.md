# Vault Fundamentals

## Vault Concepts

### Seal/Unseal
- When Vault is initially started it starts in a sealed state, meaning Vault knows where and how to access physical storage but not how to decrypt it.
- Unsealing happens by obtaining the plaintext master key used to read the decryption key to decrypt the data.
- The encryption key is also stored with the data but encrypted with another encryption key known as the 'master key'. This means to decrypt the data, Vault must decrypt the encryption key which requires the master key - unsealing is the process of getting access to this master key.
- The master key is stored alongside all other Vault data but is encrypted by another mechanism: the unseal key.
- Summary: most Vault data is encrypted using the encryption key in the keyring; the keyring is encrypted by the master key; and the master key is encrypted by the unseal key.
- Default Vault config uses a Shamir seal.
- Vault uses an algorithm known as 'Shamir's Secret Sharing' to split the key into shards. A certain number of shards is needed to reconstruct the unseal key, which is then used to decrypt the master key.
- To unseal Vault, use the 'vault operator unseal' command or use the API.
- Once Vault is unsealed, it remains unsealed until one of the below things happens:
  1. It is resealed via the API
  2. The server is restarted
  3. Vaults storage layer encounters an unrecoverable error
- There is also an API to seal the Vault. This will destroy the master key and require another unseal process to restore it. This lock method can be used if your Vault infrastructure is at risk.
- The Auto Unseal of Vault was developed to reduce the risk of keeping the unseal key unsecure. Auto Unseal allows securing the unseal key from users to a trusted device or startup.

For more info, visit: https://www.vaultproject.io/docs/concepts/seal

### Lease, Renew & Revoke
- All dynamic secrets in Vault are required to have a lease. Even if it is meant to last forever, it's required to force the user to check in routinely.
- A lease can be revoked which will invalidate the secret immediately.
- Revocation can happen by the API, via the 'vault lease revoke' command, or automatically when it expires.
- When a lease expires, Vault will revoke that lease. When a token is revoked, Vault will revoke all leases that were created using that token.
- A lease ID is a prefix which is used to manage the lease of the secret.
- The lease duration is a given TTL value in seconds.
- When renewing a lease, a user can specify an amount of time they want remaining on the lease. It is an increment from the current time and NOT an increment from the current TTL.
- Operators can also revoke multiple secrets based on their lease ID prefix. For example, to revoke all AWS access keys you can do 'vault lease revoke - prefix aws/'.

For more info, visit: https://www.vaultproject.io/docs/concepts/lease

### Authentication
- Authentication in Vault is a process whereby the user or machine supplied information is verified against an external system. These methods include GitHub, LDAP, AppRole and more.
- Before a client can interact with Vault it must authenticate to it. Once authenticated a token is generated and used for that session. This token may have an associated policy with it.
- Use 'vault write sys/auth/my-auth type=userpass' to enable the "userpass" auth method at the path "my-path"
- Vault supports multiple auth methods simultaneously and you can even mount the same type of auth method at different paths.
- To authenticate with the CLI use 'vault login'. For example, to authenticate with GitHub, you can do: 'vault login -method=github token=<token>'. The CLI will also output your raw token which is used for revocation and renewal.
- You can also authenticate via the API though this is typically used for machine authentication. For example the GitHub login endpoint is located at 'auth/github/login'
- Identities have lease associated with them in the same way secrets do. This means you must reauthenticate after the given lease period to continue accessing Vault. You can use the 'vault token renew <token>' to reauthenticate.

For more info, visit: https://www.vaultproject.io/docs/concepts/auth

### Tokens
- Tokens can be used directly or auth methods can be used to dynamically generate tokens based on external identities.
- The first method of authentication is the initial root token you're given on setup - this auth method also cannot be disabled.
- All external authentication mechanisms (such at GitHub) have the same properties as a normal manually created token.
- Within Vault tokens map to information. This information is what policies are set, controlling what the token holder can and cannot do within Vault. Other information includes metadata.
- There are two types of tokens: service tokens and batch tokens.
  - Service Tokens: what we would think of as normal Vault tokens. Renewal, revocation, creating child tokens etc are what's supported. Leases created with service tokens are tracked along with the service token and revoked when the token expires.
  - Batch Tokens: encrypted blobs that carry enough information for them to be used for Vault actions but require no storage on disk to track them. Because of this they lack flexibility but are extremely lightweight. Leases created by batch tokens are constrained to the remaining TTL of the batch token.
- The Token Store is an authentication backend which is responsible for creating and storing tokens and cannot be disabled. It is also the only auth method that has no login capability.
- Root Tokens are tokens that have the root policy attached to them, which means they can do anything in Vault.
- There are only 3 ways to create root tokens:
  - 'vault operator init' time
  - By using another root token
  - By using 'vault operator generator-root'
- When a token holder generates new tokens, those tokens will be children of the original token. When a parent token is revoked, all child tokens are revoked too. This is to ensure a user cannot escape revocation by generating a never-ending tree of child tokens.
  - Sometimes the above behaviour isn't appropriate, so users can create orphan tokens which have no parent.
  - To create Orphan tokens you need to have the relevant permissions:
    - 'write' access to the 'auth/token/create-orphan' endpoint
    - By having 'sudo' or 'root' access to the 'auth/token/create' and setting the 'no_parent' paramater to 'true'.
    - Via Token Store roles
    - By logging in with any other non-token auth method
- When tokens are created a token accessor is also created and returned. This accessor can perform the following actions:
  - Look up a tokens properties
  - Look up a tokens capabilities on a path
  - Renew the token
  - Revoke the token
- Listing the tokens via the 'auth/token/accessors' command can be dangerous as it will list all accessors which can in turn be used to revoke all tokens.
- All non-root tokens have a TTL associated with it. Root tokens may have a TTL associated with it, but the TTL value could also be 0 - meaning it never expires.
- To extend the token validity, use the 'vault token renew' command or the appropriate renewal endpoint.
- Where there is neither a period or maximum TTL value set on the token, its lifetime will be compared to the maximum TTL. This value is dynamically generated and can change from renewal to renewal.
- Periodic tokens allows for havng a long-running token open for an SQL connection for example. You can create periodic tokens by either of the following:
  - By having 'sudo' capability or 'root' token with the 'auth/token/create' endpoint.
  - By using Token Store roles
  - By using an auth method that supports issuing these (such as AppRole)
- The TTL of a periodic token will be equal to the configuration period and at renewal time, the TTL will be reset back to this configuration period as long as the token is successfully renewed.
- The idea behind periodic tokens is that it is easy for systems and services to perform an action frequently, for example every 2 hours or 5 minutes. As long as the system is actively renewing this token it will keep using it and any associated leases.
- Some tokens are able to be bound to CIDR ranges to restrict which client IP's are allowed to use them.

For more info, visit: https://www.vaultproject.io/docs/concepts/tokens

### Response Wrapping
- Response Wrapping is the idea that when a secret is requested (TLS private key for example), Vault can take that response it would have sent to an HTTP client, inserted it into the cubbyhole of a single-use token, returning that single-use token instead. This response is wrapped by the token and retrieving it requires unwrapping.
- It ensures that the value being transmitted is not the actual secret but a reference to a secret.
- It provides interception/tampering detection, ensuring that only a single party can unwrap the token.
- It also limits the lifetime of secret exposure because the token has a lifetime that is separate from the wrapped secret.
- When a response is wrapped it contains the following: 
  - TTL of the response-wrapping token
  - The token value
  - Creation time of the response-wrapping token
  - Creation path
  - Wrapped accessor
- Via the sys/wrapping path, you can do the following:
  - Lookup the response-wrapping token's creation time, path, TTL etc. This path is unauthenticated
  - Unwrapping the token
  - Rewrapping the token
  - Wrapping the token

For more info, visit: https://www.vaultproject.io/docs/concepts/response-wrapping

### Policies
- Policies provide a way to grant or forbid access to paths or operations within Vault. It is a deny all by default.
- Vault setup:
  - Security team configures Vault against an Auth method (such as LDAP)
  - The security team will then write up a policy which grants access to paths in Vault
  - This policy is then stored in Vault and referenced by name
  - The security team will then map data in the auth method to a policy. For example: "Members of the OU group 'dev' map to the policy named 'readonly-dev'"
- Once this has complete, when a user authenticates Vault, they will automatically pick up the delegated policy. In this process Vault will generate a token and attach the policies to that token. This token is then returned to the user.
- If the user has to re-auth, they will be presented with a new token.
- Authenticating a second time does not invalidate the original token.
- Each path must define one or more capabilities which provides the fine-grained control over operations. These include:
  - create, create & update, read, update, delete, list
  - In addition to standard set above: sudo, deny
- Finer grained controls can be set at given paths. For example, asking for required, allowed or denied parameters at a given path.
- Vault has 2 built in policies which are default and root:
  - Default Policy
    - By default, this policy is attached to all tokens but may be excluded at token creation time by supporting auth methods
    - To view permissions of the default policy, use 'vault read sys/policy/default'
    - To disable attachment of the default policy use 'vault token create -no-default-policy'
  - Root Policy
    - Any user associated with this policy becomes a root user
    - The root token should be revoked once Vault is configured. To do this, run 'vault token revoke "<token>"'
- To create a new policy, run the 'vault policy write policy-name policy-file.hcl' command.
- To update an existing policy, run the 'vault write sys/policy/my-existing-policy policy=@updated-policy.json' command.
- To delete a policy, run the 'vault delete sys/policy/policy-name' command.

For more info, visit: https://www.vaultproject.io/docs/concepts/policies

### Password Policies
- A password policy is a set of instructions on how to generate a password. Not all secrets engines utilise password policies, so check the documentation for supported secrets engines.
- Passwords are randomly generated frm the de-duplicated union of charsets found in all rules and then checked against each of these rules to determine if the candidate password is valid according to the policy.
- To generate a password, three things are needed:
  - A cryptographic random number generator - this generates N numbers that correspond into the charset where N is the length of password we wish to use
  - A character set (charset) to select characters from
  - The password length
- Preventing bias has also been taken into consideration. This is where some of the first characters in a charset can be selected more frequently than the remaining characters.
- Password policies are defined in HCL or JSON.
- Available parameters for configuring password policies:
  - length - specifies how long the password will be. Must be >=4.
  - charset - string representation of the charset that the rule observes. For example 'abcdefghijkl'
  - min-chars - the minimum number of characters from that charset

For more info, visit: https://www.vaultproject.io/docs/concepts/password-policies

### High Availability

For more info, visit: 

### Integrated Storage

For more info, visit: 

### PGP, GPG & Keybase

For more info, visit: 

### Recovery Mode

For more info, visit: 

### Resource Quotas

For more info, visit: 

### Client Count

For more info, visit: 

### Transform

For more info, visit: