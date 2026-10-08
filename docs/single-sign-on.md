## Single sign-on with OpenID Connect

Fizzy can sign people in through one OpenID Connect (OIDC) identity provider for the whole server. (OpenID Connect is a sign-in layer on top of OAuth 2.0.) This guide lists what Fizzy needs from the provider. This document uses [Keycloak](https://www.keycloak.org/) in its examples.

Once single sign-on (SSO) is configured, it will be the only way to log in to Fizzy. Magic links, passkeys, auto-login links, signups by email, join links, and personal access tokens will stop working. When you remove the SSO configuration, Fizzy will work as before.

On a new server with no account, the first person who signs in through SSO will create the first account. That person will become its owner.

### Provider requirements

Fizzy works with an OpenID Connect provider which meets these requirements:

- The provider publishes a discovery document at `<issuer>/.well-known/openid-configuration`.
- The provider supports the authorization code flow with PKCE `S256`.
- The provider allows the redirect URI `https://fizzy.example.com/session/single_sign_on/callback`.
- The token endpoint can take the client secret in the request body (`client_secret_post`) or in the `Authorization` header (`client_secret_basic`). If the discovery document lists `client_secret_post`, Fizzy will use the request body.
- The provider signs ID tokens with an RSA or EC key. ID tokens that use an HMAC algorithm, such as HS256, will not work with Fizzy.
- The ID token contains `email` and `email_verified`. Fizzy will read only the ID token. It will not call the userinfo endpoint.
- If the token or key endpoint is on a host other than the issuer host, that host must resolve to a public address.

The first time a person signs in, Fizzy will link them to the Fizzy identity with the same email address. For this first sign-in, `email_verified` must be `true`. After that, Fizzy will find the person by the `sub` claim, which is their user ID in the provider. If your provider does not send `email_verified`, nobody will be able to sign in.

Fizzy asks for the scopes `openid`, `email`, and `profile`. If the discovery document lists the `groups` scope, Fizzy will also ask for `groups`. For that, allow the `groups` scope for the Fizzy client in your provider.

When SSO is configured, each account in Fizzy can be associated with a group. The group determines the users allowed to access the account. Fizzy will read groups from the `groups` claim of the ID token:

- Fizzy will read each `/` in a group name as a step from a parent group to a child group.
- If a group name does not start with `/`, Fizzy will add one on its own.
- If your provider does not send a `groups` claim, the group features will not work. In that case, only owners will be admins, nobody will be able to create additional accounts, and no new users can join any existing accounts.

### Identity Provider Setup Example (Keycloak)

#### Create the client

1. In the Keycloak admin console, open _Clients_ and create a client.
2. Set _Client type_ to _OpenID Connect_ and enter a _Client ID_, for example `fizzy`.
3. Turn on _Client authentication_.
4. Keep _Standard flow_ on. Make sure _Direct access grants_ and _Implicit flow_ are off.
5. Set _Valid redirect URIs_ to `https://<fizzy_server_hostname>/session/single_sign_on/callback`.
6. Save the client.
7. On the _Credentials_ tab, copy the _Client secret_.

#### Send the groups of each user

1. On the _Client scopes_ tab of the client, open `fizzy-dedicated` (if you set your Client ID as `fizzy`).
2. Add a new mapper of the type _Group Membership_.
3. Set _Name_ to `groups`.
4. Set _Token Claim Name_ to `groups`.
5. Turn on _Full group path_ and _Add to ID token_.
6. Save the mapper.

#### Prepare the users

- Every user needs an email address.
- The email address must be verified in Keycloak. For users that you create in the admin console, turn on _Email verified_.
- By default, every Keycloak user will be able to sign in to every client. To limit who can use Fizzy, restrict access to the Fizzy client in Keycloak.

In Keycloak, the issuer URL will look something like `https://<keycloak_server_hostname>/realms/acme`. Replace `acme` with the name of the Keycloak space that holds your users and the `fizzy` client.

### Configure Fizzy

Set these environment variables:

- `SINGLE_SIGN_ON_ISSUER`: the issuer URL of the provider, for example `https://id.example.com`. It has to use `https`.
- `SINGLE_SIGN_ON_CLIENT_ID`: the client ID, for example `fizzy`.
- `SINGLE_SIGN_ON_CLIENT_SECRET`: the client secret.
- `SINGLE_SIGN_ON_PROVIDER_NAME` (optional): the name of the identity provider, which will be shown in some places around Fizzy, for example `Acme SSO`. The default value is `SSO`.
- `SINGLE_SIGN_ON_REAUTHENTICATION_HOURS` (optional): how often a session must sign in through the provider again. The default value is `12`. If the user still has an active session with the provider, they will not have to enter their password again in the SSO login page. To configure how often users must enter their password, change the session configuration of the provider.
- `SINGLE_SIGN_ON_ADMIN_GROUP` (optional): the full path of the group whose members are admins of every account, for example `/fizzy/admin`.
- `SINGLE_SIGN_ON_ACCOUNT_ADMIN_SUBGROUP` (optional): the name of the subgroup whose members are admins of one account, for example `admin`.

The content security policy lets forms send people to the issuer host. If the authorization endpoint of your provider is on a different host, add that host to `CSP_FORM_ACTION`.

### Limit an account to a group

Each account can have one group from the provider. The SSO group field sits below the list of people of the account. Only members of the admin group (`SINGLE_SIGN_ON_ADMIN_GROUP`) can change it. Be sure to enter the full group path, for example `/fizzy/engineering`. Some things to note:

- With a group, only members of the group and of the admin group can open the account.
- When no group is specified for an account, every user in the provider can access it, given that they are a member of that account. For example, they can be members from before SSO was configured. And Fizzy automatically adds members of the admin group to accounts of that sort.
- Fizzy counts a member of a subgroup as a member of its parent groups. For example, a member of `/fizzy/engineering/admin` can open an account assigned to the group `/fizzy/engineering`.
- Fizzy matches whole group names. The groups `/sales` and `/europe/sales` will be considered different.
- A member of an account who is not in the group will keep seeing the account listed right after login. But access to that account will be denied.
- If an admin removes a person who is still in the group, that person can come back at the next sign-in. To keep the person out, remove them from the group through the provider.

### Manage admins with groups

Groups in the provider determine who is an admin. This is why the role buttons in the list of people are disabled. At each sign-in, Fizzy sets the role of the person in each of their accounts:

- A member of `SINGLE_SIGN_ON_ADMIN_GROUP` is an admin of every account. Fizzy adds this person to every account, and they can open every account whatever its group.
- A member of the account admin subgroup is an admin of that account. Fizzy concatenates `SINGLE_SIGN_ON_ACCOUNT_ADMIN_SUBGROUP` to the end of the account group string. For example, with the subgroup `admin`, the admins of the account with the group `/fizzy/engineering` are the members of `/fizzy/engineering/admin`.
- The owner of an account will stay as the owner, whether the account existed before SSO was configured or was created through SSO.
- A user who leaves the admin group will stay as member on accounts without a specified group. (To make the provider decide all access, be sure to give every account a group.)

### Turn off SSO in an emergency

In the event that your provider goes down and people cannot sign in, remove the `SINGLE_SIGN_ON_*` variables and restart Fizzy. Fizzy will go back to using magic links and passkeys, and it will ignore the account groups. People will keep the roles from their last SSO sign-in, and the role buttons will work again.

To remove the group of one account, open a Rails console on the server and run:

```ruby
account = Account.find_by(external_account_id: 123)
account.update!(single_sign_on_group: nil)
```

Replace `123` with the number at the start of the account URL.
