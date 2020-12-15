# Vault Commands

## Secrets Engines

### Writing a Secret
vault kv put <path> <key>=<value>

### Getting a Secret
Prints all secrets at given path
vault kv get <path>

Prints secret of a given field
vault kv get -field=<key_name> <path>

### Deleting a Secret
vault kv delete <path>

### Enable a Secrets Engine
vault secrets enable -path=<type> <path name>

View Vault secrets engines
vault secrets list

### Disable a Secrets Engine
When disabled all secrets are revoked & Vault data and configuration are removed
vault secrets disable <path>


## Dynamic Secrets

### Enable AWS Secrets Engine
vault secrets enable -path=aws <path name>

Configure the AWS Secrets Engine with your creds
vault write aws/config/root \
    access_key=$AWS_ACCESS_KEY_ID \
    secret_key=$AWS_SECRET_ACCESS_KEY \
    region=us-east-1

Create a role (permit all EC2 actions)
vault write aws/roles/my-role \
        credential_type=iam_user \
        policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1426528957000",
      "Effect": "Allow",
      "Action": [
        "ec2:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF

### Generate the AWS Secret
vault read aws/creds/<name>
Key                Value
---                -----
lease_id           aws/creds/my-role/0bce0782-32aa-25ec-f61d-c026ff22106e
lease_duration     768h
lease_renewable    true
access_key         AKIAJELUDIANQGRXCTZQ
secret_key         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
security_token     <nil>

NOTE: the lease_id is used for revocation, renewal & inspection

### Revoke the Secret
Using the lease_id above, you can now revoke those credentials
vault lease revoke <lease_id>


## Built-In Help
Offers build in help on specific enabled path for Vault
vault path-help <path name>


## Authentication

### Token Authentication
By default when creating a new token it will inherit the policies from it's parent
vault token create

Login with a different token
vault login <token ID>

Revoke a token
vault token revoke <token ID>

### Auth Methods
Enable a new auth method (GitHub)
vault auth enable github

GitHub auth method requires an GitHub organisation to be configured. This maintains a list of users who are able to authenticate via GitHub
vault write auth/github/config organization=<org name>

Configure members of the engineering team to be assigned 'default' and 'applications' policies on login
vault write auth/github/map/teams/engineering value=default,applications

Display enabled auth methods
vault auth list

Learn more about the auth methods
vault auth help <auth method>

Login with the GitHub auth method. GitHub will ask for a PAT to be supplied
vault login -method=github OR vault login -method=github -token=<GitHub PAT>

Disable GitHub auth method
vault auth disable github


## Policies
Read a policy
vault policy read <policy name>

Write a policy
vault policy write <policy name>

List policies
vault policy list

Create a token and add a policy to it
vault token create -policy=<policy name>

### Associate Policies to Auth Methods
token_policies parameter allows for policies to be attached to auth methods. For example, the below permits 'my-policy' to be attached to the approle auth method:
vault write auth/approle/role/my-role \
    secret_id_ttl=10m \
    token_num_uses=10 \
    token_ttl=20m \
    token_max_ttl=30m \
    secret_id_num_uses=40 \
    token_policies=my-policy

