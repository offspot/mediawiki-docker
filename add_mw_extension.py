#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# author : Florent Kaisser
# maintainer : kiwix

# usage : ./add_mw_extension.py MEDIAWIKI_EXT_VERSION WIKI_DIR Extension1 Extension2 ...
#
# Fetches extensions from their GitHub mirror (github.com/wikimedia/
# mediawiki-extensions-<Name>), falling back to master if the requested
# branch doesn't exist.

import sys
import urllib.request
from pathlib import Path
from subprocess import call
from urllib.error import HTTPError, URLError

GITHUB_ARCHIVE_URL = "https://github.com/wikimedia/mediawiki-extensions-{}/archive/refs/heads/{}.tar.gz"
USER_AGENT = (
    "offspot-mediawiki-docker/add_mw_extension "
    "(https://github.com/offspot/mediawiki-docker)"
)
TMP_ARCHIVE = Path("/tmp/extension.tgz")

if len(sys.argv) <= 3:
    print("usage: add_mw_extension MEDIAWIKI_EXT_VERSION WIKI_DIR Extension1 [Extension2 ...]")
    sys.exit(1)

extension_version = sys.argv[1]
mediawiki_path = Path(sys.argv[2])

for extension_name in sys.argv[3:]:
    branch = extension_version
    url = GITHUB_ARCHIVE_URL.format(extension_name, branch)

    try:
        print(f"[{extension_name}] Checking {branch} branch")
        head_req = urllib.request.Request(
            url, headers={"User-Agent": USER_AGENT}, method="HEAD"
        )
        urllib.request.urlopen(head_req)
    except HTTPError as e:
        if e.code != 404:
            print(f"[{extension_name}] error checking extension branch: {e}")
            sys.exit(2)
        print(f"[{extension_name}] no {branch} branch, falling back to master")
        branch = "master"
        url = GITHUB_ARCHIVE_URL.format(extension_name, branch)
    except URLError as e:
        print(f"[{extension_name}] error reaching GitHub: {e}")
        sys.exit(2)

    try:
        print(f"[{extension_name}] Download extension ({branch})")
        get_req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(get_req) as response:
            TMP_ARCHIVE.write_bytes(response.read())
    except (HTTPError, URLError) as e:
        print(f"[{extension_name}] error downloading extension: {e}")
        sys.exit(3)

    print(f"[{extension_name}] Extract files")
    dest = mediawiki_path / "extensions" / extension_name
    dest.mkdir(parents=True, exist_ok=True)
    # GitHub archives wrap content in a <repo>-<branch>/ folder; strip it so
    # files land directly under extensions/<Name>/ as MediaWiki expects.
    if call(["tar", "-xzf", str(TMP_ARCHIVE), "--strip-components=1", "-C", str(dest)]) > 0:
        print(f"[{extension_name}] error extracting extension tarball")
        sys.exit(4)

    TMP_ARCHIVE.unlink()
