# Sign-in

## How it works

The app uses WordPress.com's **implicit grant** (`response_type=token`, `scope=global`). It has no client secret, so the client ID can ship in the app and nobody has to register their own app. Studio and the WordPress.com desktop app use the same grant.

1. On **Connect**, `OAuth.authorize()` opens a loopback-only listener on a port macOS picks (port 0), then opens `public-api.wordpress.com/oauth2/authorize` in the browser with `redirect_uri=http://localhost:<port>/callback`.
2. After approval, WordPress.com redirects to `/callback#access_token=…`. Browsers don't send fragments to servers, so `/callback` serves a tiny page that forwards the fragment to `/token?…`.
3. `/token` checks `state` and returns the token to the app.

The token is stored in `credentials.json` and lasts about 14 days, with no refresh token. When it expires, or the API returns `invalid_token` or a 401, the app shows "Session expired" and the user clicks Reconnect.

## App registration

| | |
|---|---|
| Client ID | `151672` (`OAuth.clientID`), "Dispatch for WordPress.com", owned by Shaun |
| Type | Native |
| Redirect URL | `http://localhost`, with no port or path |

WordPress.com accepts any redirect URI that **starts with** the registered one on the **same host**, so each sign-in can use a different port. See `OAuth2::redirect_uri_is_valid()` in wpcom's `mu-plugins/oauth2/oauth2.php`.

Before wide distribution, swap the client ID for an Automattic-owned app.

## Things we tried that don't work

- **Custom URL scheme (`wpnotifications://auth`).** WordPress.com only redirects to custom schemes that are hardcoded in `OAuth2::CUSTOM_PROTOCOLS`: `wpdesktop`, `wpcom-local-dev` and `wp-studio`. For any other scheme the approval page sets `is_custom_protocol=0` and never redirects. Setting the app type to Native doesn't change that. The only fix is a wpcom change that adds the scheme to that list.
- **Code flow (`response_type=code`).** It needs the client secret, which can't ship in a distributed app.
- **OAuth 2.1 server (`/oauth2-1`: PKCE, dynamic registration, refresh tokens).** Its tokens get `invalid_token` from REST v1.1 and v1.2, even with resource indicators. They appear to be scoped to the MCP endpoint.
