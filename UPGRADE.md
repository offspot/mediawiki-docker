# Upgrading MediaWiki in this image

This is the reusable runbook for bumping this image to a new MediaWiki
version and rolling that out to the wikis it runs (currently openzim,
kiwix). Keep this document generic — version-specific details (what broke,
what config had to change) go in a dated section at the bottom instead, so
this doesn't need rewriting every time.

## Policy

- Track MediaWiki **LTS releases only**. Skip non-LTS releases entirely —
  they carry a much higher rate of extension-breaking changes for a
  one-year support window instead of three.
- Rebuild and re-tag the image on **every new LTS patch release**
  (`MEDIAWIKI_VERSION` bump only). The base image, apt packages
  (nginx/PHP/MariaDB) and extensions (pulled from each extension's
  matching `RELx_yy` branch) all float to current-stable on every rebuild
  by construction — no separate pinning needed beyond the MediaWiki
  version itself.
- When a new LTS lands, wait for an early patch release before adopting
  it (avoids the usual day-one breakage), then run the full rehearsal
  below before touching production.

## Image tag history

Append a row every time a tag is cut. Debian/nginx/PHP/MariaDB versions
float with the base image, so record what they actually resolved to at
build time (`docker run --rm <tag> cat /etc/os-release`,
`docker run --rm <tag> nginx -v`, `docker run --rm <tag> php -v`,
`docker run --rm <tag> mariadbd --version`) — don't guess from memory.

| Image tag | MediaWiki | PHP   | Debian (nginx base) | nginx  | MariaDB | Notes |
|-----------|-----------|-------|----------------------|--------|---------|-------|
| v1.36.1   | 1.36.1    | 7.3   | buster (10)          | 1.21.3 | 10.3.34 | superseded, PHP 7.3 EOL |
| v1.43.11  | 1.43.11   | 8.4.27| trixie (13)           | 1.30.6 | 11.8.6  | current; first LTS-only tag |
| _next 1.43.x patch_ | TBD | TBD | TBD | TBD | TBD | fill in at rebuild time |
| _1.47 LTS (future)_ | not yet released (~Nov 2026) | — | — | — | — | wait for an early patch before adopting |

## Pre-upgrade checklist (per wiki)

1. Confirm a recent borgmatic backup exists and is restorable
   (`root/.borgmatic/mysql_databases/<service>/my_wiki` mysqldump, plus
   the `storage/{config,images,site_root}` tree).
2. Read the target MediaWiki version's release notes for configuration
   changes, removed/renamed extensions, and PHP/DB version requirements.
   Cross-check every `wfLoadExtension(...)` call in both the base
   `LocalSettings.php` and the wiki's `LocalSettings.custom.php` against
   what the target version actually ships/supports.
3. Check every non-core extension (anything not fetched from
   `wikimedia/mediawiki-extensions-*`) for a branch matching the target
   version. If there isn't one, decide up front whether to patch it,
   replace it, or drop it — don't find out during the production cutover.
4. Build and push the new image (tag matching `MEDIAWIKI_VERSION`), and
   add a row to the table above with its actual resolved dependency
   versions.

## Staging rehearsal

Do this before touching production, every time. `rehearse-upgrade.sh`
(in this repo) automates the whole sequence below against a disposable
data directory:

```
./rehearse-upgrade.sh <borg-restore-root> <data-dir> <image-tag> [name] [port] [url]
```

- `<borg-restore-root>`: a freshly restored borgmatic backup root,
  containing `storage/{config,images,site_root}` and
  `root/.borgmatic/mysql_databases/<service>/my_wiki`.
- `<data-dir>`: a scratch directory to stage the container's data volume
  in (created/cleaned by the script).
- `<image-tag>`: the image to test, e.g. `ghcr.io/offspot/mediawiki:v1.43.11`.

It stages the data dir, runs the `MYSQL_INIT=1` import pass, shuts
MariaDB down cleanly, then starts the real container — which is the step
that actually runs `maintenance/update.php --quick` against the restored
data for the first time — and leaves it running for you to inspect.

Manually verify, over HTTP, in a real browser:

- The homepage and a few real content pages render fully (no partial
  page, no visible errors).
- `Special:Version` has no `Fatal error`/`Warning:`/`Deprecated:` text in
  the page (a clean page prints none of these) — this catches extensions
  that failed to register.
- Log in as **Admin** (admins have edit rights; anonymous users normally
  don't per `$wgGroupPermissions`) and make a test edit — this exercises
  the write path, not just reads.
- Image upload and thumbnail rendering.
- Anything specific to that wiki's content: search the `text` table
  (`SELECT COUNT(*) FROM text WHERE old_text LIKE '%<some feature>%'`) or
  `page_namespace = 828` for `Module:` pages to know whether a given
  extension (Scribunto, Iframe, Score, ...) actually has live content to
  exercise, since a loaded-but-unused extension tells you nothing by
  itself.

When done, stop MariaDB cleanly before tearing the container down
(`docker exec <name> mysqladmin shutdown`, then `docker stop`/`docker rm`)
— or just `docker stop` if you're on an image where `start.sh` traps the
stop signal to do this automatically (true since the 1.43 upgrade;
verify for anything older).

## Production cutover

We run on k8s with local (hostPath) volumes, so cutover is a volume copy,
not a database restore:

1. Announce a short maintenance window.
2. Take a fresh backup (don't rely solely on the last scheduled
   borgmatic run).
3. **Shut MariaDB down cleanly before touching the volume.** This depends
   entirely on whether the *currently-running* (old) image already has the
   shutdown trap added in this repo at the 1.43 upgrade — check its
   `start.sh`, don't assume:
   - If it does: scaling the old pod to 0 replicas sends it a termination
     signal that `start.sh` traps to run `mysqladmin shutdown` gracefully.
     Confirm this actually happened (check the pod's last logs for
     `Shutting down…` before it exited) rather than assuming it.
   - If it doesn't (true for the 1.36 image, and so true for this very
     first upgrade under this process): scaling to 0 just SIGKILLs
     MariaDB once the grace period expires. `kubectl exec` into the pod
     and run `mysqladmin shutdown` yourself **before** scaling down.
4. `cp -a` the volume's local directory to a new path (don't overwrite
   the old one in place — that's your rollback). Point the new
   Deployment (new image tag) at that copy.
5. Scale the new pod up. This triggers the real `update.php` run against
   production data for the first time. Watch its logs for the update
   step: success ends with `Password set. / done.` and no
   `/!\ update script failed:` line.
6. If it failed, scale the new pod back to 0 and investigate — don't
   leave it serving traffic against a partially-migrated schema.
7. Run the same manual verification as the staging rehearsal, against
   the real site.
8. Re-open the maintenance window once confirmed healthy. Keep the old
   volume copy (and the pre-cutover backup) until you're confident,
   then clean it up.

### Rollback

Scale the new pod to 0, point the old Deployment (old image tag) back at
the **original, untouched** volume path from before step 4, scale it
back up. `update.php` is additive/forward-only — if the new version's
`update.php` already ran against a volume, don't roll back the code
while serving from that same volume; restore from the step-2 backup
instead.

## Risk categories to watch for, every time

- **Unversioned or forked extensions** (no branch matching the target
  MediaWiki version) are the most common breakage source — they have no
  upstream safety net, so core API removals land on you to patch.
- **Extensions retired or dropped from the default bundle** upstream
  (happens silently between versions — check the extension still exists
  before assuming a missing-file error is a fetch problem).
- **Config variables changing type or being removed** (booleans becoming
  required arrays, etc.) — these fail at `update.php` time with a clear
  message, but only if you actually run the rehearsal.
- **Base image packaging drift** unrelated to MediaWiki itself (init
  script names, default config file contents, signal handling) — caught
  by actually running the container, not by reading diffs.
- **Downstream images built `FROM` a tag of this image** (e.g. WikiFundi)
  don't break just because a new tag exists — they stay on whatever tag
  they pin. But check whether any removed/renamed extension, PHP version,
  or service name is referenced in that downstream repo's own Dockerfile,
  `start.sh`, or `LocalSettings.custom.php`, *before* it gets rebased onto
  the new tag, not after.

---

## Upgrade notes: 1.36.1 → 1.43.11 (2026-10)

Specifics for this particular hop. Superseded by nothing yet — this was
the first upgrade run under this new process.

### Dockerfile / supply chain changes

- `extdist.wmflabs.org` (used to fetch WMF extensions) was down during
  this upgrade — Wikimedia had shut down Cloud VPS/Toolforge over the
  PHP2Shell CVEs (CVE-2026-109618/109619). `add_mw_extension.py` now
  pulls from the `wikimedia/mediawiki-extensions-*` GitHub mirrors
  instead, which is also a more resilient long-term source.
- `GettingStarted` and `LocalisationUpdate` extensions are retired
  upstream (translations are now backported directly into release
  branches) — dropped from the image and from kiwix's config.
- `Renameuser` is no longer bundled in core's tarball by default —
  fetched explicitly now.
- Dropped `BadBehaviour` (a WordPress plugin, never actually loaded by
  any config) and the `mwExtUpgrader.phar` step (an argument-less no-op
  that hard-crashes on PHP 8.4). Composer install now uses the official
  installer instead of a now-404 kiwix.org mirror.

### Debian trixie base image drift

- `/etc/init.d/mysql` renamed to `/etc/init.d/mariadb`; the MariaDB
  `datadir` config line ships commented out by default — both silently
  broke DB startup/redirection in `mediawiki-init.sh`.
- `nginx:stable-trixie` sets `STOPSIGNAL SIGQUIT` (nginx's own
  convention), which went untrapped by `start.sh` and corrupted
  MariaDB's system tables on `docker stop` before this was fixed.

### MediaWiki config/extension changes

- The committed `data/my_wiki.sqlite` starter template predated
  MediaWiki 1.35, and 1.43's `update.php` refuses anything older than
  that — a brand-new deployment with no existing wiki would have
  hard-failed on first boot. Now generated fresh at build time via
  `install.php` instead of committed as a binary.
- Math extension's PNG rendering (texvc) was removed in 1.39 — switched
  to native MathML (`$wgMathValidModes = ['native']`), dropping the
  `texlive`/`dvipng`/`ocaml` packages.
- `$wgPasswordAttemptThrottle` no longer accepts a boolean — `false`
  must become `[]`.
- `MatomoAnalytics` (unversioned miraheze fork) called the since-removed
  `User::isLoggedIn()` and the deprecated global `$wgUser` — patched in
  place rather than re-pinning to its restructured `main` branch.

### Mailgun: extension → core `$wgSMTP`

The `Mailgun` extension (`rgaudin/mediawiki-mailgun`) has been abandoned
since 2021 (no branch past `REL1_37`). Replaced with MediaWiki core's
built-in `$wgSMTP`, pointed at Mailgun's SMTP relay instead of its HTTP
API. Note the SMTP credentials are **not** the same as the old API key —
get real ones from the Mailgun dashboard before cutover.

Old (per-wiki `LocalSettings.custom.php`):

```php
# Mailgun
wfLoadExtension( 'Mailgun' );
$wgMailgunAPIKey = "<api-key>";
$wgMailgunDomain = "wiki.openzim.org";
```

New:

```php
# Mail (via Mailgun SMTP relay; replaces the abandoned Mailgun extension)
$wgSMTP = array(
	'host'     => "smtp.mailgun.org",
	'IDHost'   => "wiki.openzim.org",
	'port'     => 587,
	'auth'     => true,
	'username' => "postmaster@wiki.openzim.org",
	'password' => "<real smtp password from the Mailgun dashboard>",
);
```

Apply the same swap to kiwix's config with its own domain
(`wiki.kiwix.org`) and credentials.

### Residual risks specific to this hop

- `Iframe` (sigbertklinke) and the patched `MatomoAnalytics` (miraheze)
  forks still have no upstream version tagging matched to 1.43. They
  loaded and (for Matomo) rendered correctly in the rehearsal, but any
  future MediaWiki core change could silently break them again with no
  upstream fix to pull — budget time to re-check on the 1.47 hop.
- `Scribunto` and `Iframe` currently have no live content on either wiki
  (no `Module:` pages, no actual `<iframe>` tag usage) — loading without
  error is all that's verified; there's nothing to exercise end-to-end
  until a page actually uses them.
- `offspot/wikifundi` builds `FROM ghcr.io/offspot/mediawiki:1.36.1` and
  fully overrides `start.sh`, so nothing in this upgrade affects it today
  — checked its repo directly, no reference to any extension removed
  here. It hardcodes `php7.3-fpm` and pins the old tag explicitly, so
  whoever eventually rebases it onto 1.43 will need the same PHP/service
  name updates made here, done again in that repo.
