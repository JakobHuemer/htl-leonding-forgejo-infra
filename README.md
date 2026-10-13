# Setup Forgejo

## Docker Compose

All files for the setup can be found in the compose/ folder.

Copy `.env.template` to `.env` and fill in the secrets. How the secret can be
generated is in the comment above each secret.

Then run:

```
docker compose up -d
```

Registration is disabled, so create an admin user:

```
docker compose exec -u git forgejo forgejo admin user create \
    --admin --username <yourname> --email <yourmail> --password '<a secure password>'
```

### Woodpecker

Add an OAuth2 App to Forgejo and name it Woodpecker.
Add this redirect URL to the OAuth2 app:

`https://<woodpecker domain>/authorize`

Copy the Client ID and Client Secret into `WOODPECKER_FORGEJO_CLIENT` and
`WOODPECKER_FORGEJO_SECRET`, then run `docker compose up -d` again.

### YouTrack

Create an access token in Forgejo with read and write permission on the
repositories. Write is needed so YouTrack can create the webhook.

In YouTrack, add a VCS integration to the project, pick Gitea as the server,
enter the repository URL and the token.

Commands in commit messages need the `#` prefix:

```
fix the thing #TES-1 In Progress
```

The commit author is matched by email, so the address in git has to be the one
of the YouTrack account and the account has to be in the Committers group of the
integration. Without a match the commit is still linked but the command is
dropped.

## TODO

The Woodpecker agent is missing, so no pipeline runs yet. The host docker socket
is not an option, so it has to run against a docker-in-docker daemon.

## OLD UNSUPPOERTED - Deploy and Setup for Forgejo

To setup secrets copy the files `forgejo/secrets.env.template` and
`woodpecker/secrets.env.template`, trim the `.template` suffix and fill in the
variables. How the secret can be generated is in the comment above each secret.
Some secrets can't be set yet for woodpecker so leave them for now and don't
apply the woodpecker secrets.


Run `./setup-secrets.sh forgejo` to set up the secrets for forgejo you create in
the first step.

run

```
kubectl apply -f forgejo
```

when everything is deployed, create an admin user:

```
kube exec -n <namespace> deployments/forgejo -- su git -c \
    "forgejo admin user create --admin --username <yourname> \
    --email <yourmail> --password '<a secure password>'"
```

### Keycloak setup

This example uses the `franklyn` realm.

First, create a client on the realms:

```
ClientID: forgejo
Name: <Optional for forgejo>
-> Next

Client Authentication: ON

-> Next

Root URL: https://<forgejo domain>/
Valid Redirect URL: https://<forgejo domain>/user/oauth2/keycloak/callback
```

Then run to add the keycloak:

> TIP: If you want to auto assign the admin permission for forgejo to any user
> having a certain keycloak role, you can add:
>
> ```
> --group-claim-name <claim> --admin-group <realm admin role>
> # e.g.
> --group-claim-name roles --admin-group "franklyn-admin"
> ```
>
> to the end inside the double quotes.
> For this to work, the forgejo client must be configured to put the users roles
> in the jwt claims. The claim name must be flat because dotted paths like
> "realm_access.roles" don't work.

```
kube exec -n <namespace> deployments/forgejo -- su git -c \
 "forgejo admin auth add-oauth \
   --name keycloak \
   --provider openidConnect \
   --key forgejo \
   --secret '<client secret copied from keycloak>' \
   --auto-discover-url https://<keycloak domain>/realms/<realm>/.well-known/openid-configuration \
   --scopes openid --scopes profile --scopes email"
```

Now you can log in with a user account.
When on the sign in page, you can click "Log In with Keycloak".

## 2 Options: 1. Woodpecker setup

Add an OAuth2 App to Forgejo and name it Woodpecker.
Add this redirect URL to the OAuth2 app:

`https://<woodpecker domain>/authorize`

Copy the Client ID and Client Secret and put it in the woodpecker secrets
(`woodpecker/secrets.env`).

Then setup the secrets:

```
./setup-secrets.sh woodpecker
```

Then deploy woodpecker:

```
kubectl apply -f woodpecker
```

The deployment already has an agent it deploys and connects to woodpecker.
This is necessary as users can't just add own runners for their orgs/repos
like you can do with forgejo actions.

> NOTE: Build logs are currently written into the database, which will grow it
> a lot over time. To keep them out of the database, set
> `WOODPECKER_LOG_STORE=file` and `WOODPECKER_LOG_STORE_FILE_PATH` on the
> server and give it its own PVC for that path.

## 2 Options: 2. Forgejo Actions

Users can add their own repo/org level runners so this is not mandatory for admins.
Woodpecker does not support this.

