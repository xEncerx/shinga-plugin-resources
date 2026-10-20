> Created: `2026-10-15T17:26:41Z` (UTC).

# Creating a Shinga Plugin — v1

A source plugin consists of a manifest and one Dart script. The manifest declares identity, settings, and network hosts; the script implements search, title metadata, and optional home content and reader URLs.

## Contents

1. [Create the manifest](#1-create-the-manifest)
2. [Write the script](#2-write-the-script)
3. [Check the source](#3-check-the-source)
4. [Signing](#signing)

## 1. Create the manifest

Follow the [manifest reference](manifest.md). Use `manifestVersion: 1`, `pluginApiVersion: 1`, a stable reverse-DNS `id`, a SemVer release `version`, and an `entry` pointing to the Dart file. Declare only the network hosts and settings you need.

The executable source has two files:

```text
manifest.json
index.dart
```

`index.dart` is an example entry name, not a fixed requirement; a safe nested path is allowed. Do not put credentials in either file. Network declarations request access; user-approved permissions are still required.

## 2. Write the script

Follow the [Dart script reference](script.md), starting with [script structure](script.md#script-structure) and the [complete example](script.md#complete-script-example).

Implement the three required methods:

- `getSearchSchema` — local search fields and sorts, or an empty schema.
- `search` — one page of title previews and optional continuation.
- `getTitle` — full metadata for a stable source-local title ID.

Implement `getHome` and `getInitialReadUrl` only when supported. Use the inherited `context` for settings, persistent storage, HTTP, logs, and runtime information. Provider fields do not persist between calls.

## 3. Check the source

Before signing the final files, check:

- The manifest and script pass validation for API v1.
- Query-only search works without local defaults; declared filters, exclusions, and sorts are actually applied.
- Pagination continues the same query and stops with `nextContinuation: null`.
- Search/home IDs resolve through `getTitle`; missing metadata remains absent rather than fabricated.
- Missing titles, rate limiting, unavailable sources, and unsupported operations use the appropriate [errors](script.md#errors), not empty successful responses.
- Optional settings and denied network access are handled deliberately; secrets are never logged.
- Results, cached values, and HTTP requests remain within [limits](script.md#limits).

Validation is not a substitute for exercising the methods against the site's actual responses. This guide specifies authoring contracts, not editor controls or a testing UI.

## Signing

Signing is currently a separate tooling-script step; it is not code to put in the restricted plugin entry. Run it in a Dart environment with the `plugin_runtime` and `plugin_protocol` packages available. The plugin script cannot import these tooling APIs.

1. Create an Ed25519 key once using `await PluginSigningService().generateKeyPair()`. Store its `.privateKeySeed` securely as raw 32-byte data outside the plugin and source control. The service does not save it for you.
2. Reuse that seed for later releases. The public key identifies the signer; changing the plugin's `id` or name cannot establish publisher identity, and generating a new key changes signer identity.
3. Sign the final exact manifest and entry bytes. Serialize the result with `.toBytes()` to obtain `signature.json` metadata.

For example, save this separate tooling script as `sign.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:plugin_protocol/plugin_protocol.dart';
import 'package:plugin_runtime/plugin_runtime.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    throw ArgumentError('Usage: sign.dart <source-dir> <seed-file> <signature-file>');
  }
  final root = Directory(args[0]).absolute.uri;
  final manifestBytes = await File.fromUri(root.resolve('manifest.json')).readAsBytes();
  final parsed = PluginManifestParser().parse(utf8.decode(manifestBytes));
  if (!parsed.isSuccess) throw const FormatException('Invalid manifest');
  final entryPath = parsed.manifest!.entry.value;
  final entryBytes = await File.fromUri(root.resolve(entryPath)).readAsBytes();
  final seed = await File(args[1]).readAsBytes();
  final signed = await const PluginSigningService().sign(
    privateKeySeed: seed,
    manifestBytes: manifestBytes,
    entryPath: entryPath,
    entryBytes: entryBytes,
  );
  await File(args[2]).writeAsBytes(signed.toBytes());
}
```

Run it with an existing seed file, for example:

```sh
dart run sign.dart ./source /secure/publisher.seed ./signature.json
```

Keep tooling, private keys, and signature output separate from the two-file executable source. Signature metadata accompanies the signed source; it is not an additional executable file or an import. The signing service creates metadata, not an installable archive, and signing does not validate the script's API implementation.

Any change to the manifest, entry path, or script bytes requires a new signature, including whitespace and line endings. Formatting or editing after signing invalidates the signature. The signature does not include its own metadata file or unrelated development files.

A valid signature proves that the covered bytes were signed by that key. It does **not** make the code safe, approve permissions, or automatically confer trusted-publisher status. A valid signature from an unrecognized key is `unknownSigned`; application-recognized keys may be classified as `trustedPublisher` or `shingaDeveloper`. Missing signature metadata is `unsigned`; malformed or mismatched metadata is `invalid`.

[Manifest reference](manifest.md) · [Dart script reference](script.md)
