> Created: `2026-10-15T17:24:38Z` (UTC).

# Plugin Manifest v1

[Plugin authoring](README.md) · [Dart script reference](script.md)

`manifest.json` identifies the plugin, selects its API and entry file, requests network access, and declares user settings. It can be read without executing the script.

## Contents

- [Plugin Manifest v1](#plugin-manifest-v1)
  - [Contents](#contents)
  - [File and JSON rules](#file-and-json-rules)
  - [Complete example](#complete-example)
  - [Root fields](#root-fields)
    - [Plugin ID](#plugin-id)
    - [Versions](#versions)
    - [Entry path](#entry-path)
    - [Icon](#icon)
  - [Localized text](#localized-text)
  - [Permissions](#permissions)
  - [Settings](#settings)
    - [Setting types and defaults](#setting-types-and-defaults)
    - [Options](#options)
    - [Required values and script access](#required-values-and-script-access)

## File and JSON rules

- Place `manifest.json` at the package root as a regular file, not a symbolic link.
- Use valid UTF-8 JSON with an object at the root. The default file-size limit is 256 KiB (262144 bytes), including whitespace and any BOM; the application may impose a smaller limit.
- One UTF-8 BOM at the very beginning is accepted. A second leading BOM is not.
- Field names and setting type names are case-sensitive. Values must have the stated JSON type; no string-to-number or other coercion is performed. Integer fields require integers such as `1`, not `1.0`.
- **Unknown fields are errors**, including fields inside network permissions, settings, and options. Unknown permission names and setting types are also errors.
- **Optional means omittable, not nullable.** Explicit `null` is invalid for all defined manifest fields, including optional fields and defaults. Null collection elements are invalid too.
- Use unique JSON member names. Do not rely on the parser to detect duplicate source member names. Array-level uniqueness and duplicate normalized locales are validated as described below.

## Complete example

This example targets the API described in this documentation. Only declare settings and hosts your source actually needs.

```json
{
  "manifestVersion": 1,
  "id": "com.example.manga",
  "name": "Example Manga",
  "version": "1.0.0",
  "pluginApiVersion": 1,
  "entry": "index.dart",
  "icon": "https://example.com/favicon.ico",
  "permissions": {
    "network": {
      "hosts": ["api.example.com", "*.cdn.example.com"]
    }
  },
  "settings": [
    {
      "id": "searchPrefix",
      "type": "text",
      "label": {"en": "Search prefix"},
      "defaultValue": ""
    },
    {
      "id": "apiToken",
      "type": "secret",
      "label": {"en": "API token"},
      "description": {"en": "Optional token for **authenticated requests**."}
    },
    {
      "id": "adultContent",
      "type": "boolean",
      "label": {"en": "Adult content"},
      "defaultValue": false
    },
    {
      "id": "minimumRating",
      "type": "num",
      "label": {"en": "Minimum rating"},
      "defaultValue": 7.5
    },
    {
      "id": "contentLanguage",
      "type": "select",
      "required": true,
      "label": {"en": "Content language"},
      "defaultValue": "en",
      "options": [
        {"value": "en", "label": {"en": "English"}},
        {"value": "ja", "label": {"en": "Japanese"}}
      ]
    },
    {
      "id": "genres",
      "type": "multiSelect",
      "label": {"en": "Preferred genres"},
      "defaultValue": ["action"],
      "options": [
        {"value": "action", "label": {"en": "Action"}},
        {"value": "comedy", "label": {"en": "Comedy"}}
      ]
    }
  ]
}
```

## Root fields

| Field | JSON type | Required | If omitted / rule |
| --- | --- | --- | --- |
| `manifestVersion` | integer | Yes | Exactly `1`. |
| `id` | string | Yes | Lowercase reverse-DNS plugin identifier. |
| `name` | string | Yes | Nonblank user-facing name, not a localized-text object. |
| `version` | string | Yes | Plugin release version in SemVer 2.0.0 format. |
| `pluginApiVersion` | integer | Yes | Positive API version; use `1` for this guide. |
| `entry` | string | Yes | Safe package-relative path to the script. |
| `icon` | string | No | No icon. Otherwise an absolute HTTP(S) image URL. |
| `permissions` | object | No | No requested permissions. |
| `settings` | array of objects | No | No settings. |

### Plugin ID

Use a stable globally unique identifier such as `com.example.manga`:

- At least two dot-separated segments, at most 253 characters in total.
- Each segment has 1–63 lowercase ASCII letters, digits, or interior hyphens.
- A segment cannot start or end with a hyphen. Uppercase and non-ASCII characters are invalid.
- No automatic trimming or normalization is performed.

The plugin ID identifies the source; it does not prove the publisher's identity. See [signing](README.md#signing).

### Versions

These fields have different purposes:

- `manifestVersion` selects the manifest format.
- `pluginApiVersion` selects the script API. Manifest parsing accepts any positive integer, but the application must support that exact API to run the script.
- `version` identifies a release of your plugin. Follow [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html), for example `1.0.0`, `1.2.3-alpha.1`, or `2.0.0+build.5`. Do not use a `v` prefix or leading zeroes in numeric core/prerelease components.

### Entry path

For a Dart v1 script, use a lowercase `.dart` extension, for example `index.dart` or `dist/index.dart`. The file must exist at that exact case-sensitive path. An unsupported extension cannot be executed.

Path rules:

- Relative, with `/` separators only. Absolute paths, drive paths, URLs, `:`, and backslashes are invalid.
- No empty segments, `.` or `..` segments, or trailing dots/spaces in any segment.
- No ASCII control characters U+0000–U+001F or `<`, `>`, `"`, `|`, `?`, `*`.
- No Windows device names, case-insensitively: `CON`, `PRN`, `AUX`, `NUL`, `CLOCK$`, `CONIN$`, `CONOUT$`, `COM1`–`COM9`, or `LPT1`–`LPT9`; `COM`/`LPT` followed by superscript `¹`, `²`, or `³` are also reserved. The name before the first dot is checked, so `con.dart` is invalid too.

Only the entry file contains executable author code; it cannot import other package files. See [script structure](script.md#script-structure).

### Icon

`icon` must be an absolute HTTP or HTTPS URL with a nonempty host. Its URL path must end, case-insensitively, in one of:

```text
.ico .gif .webp .png .jpg .jpeg .avif .bmp .svg .svgz .tif .tiff .apng
```

The extension check uses the path; a query string does not replace the required image extension. A site's favicon may be used when it meets these rules.

## Localized text

Setting labels, option labels, and setting descriptions are objects mapping locale tags to strings:

```json
{"en": "Content language", "en-GB": "Content language"}
```

- Supply at least one locale. Every value must be a nonblank string; the original string is preserved, not trimmed.
- Supported tags use `language[-Script][-REGION]`: 2–8 ASCII language letters, optional four-letter script, optional two-letter or three-digit region. Use `-`, not `_`; variants and extensions are not supported.
- Tags normalize as `EN` → `en`, `hans` → `Hans`, `us` → `US`; numeric regions are preserved. Distinct keys that normalize to the same tag are an error, such as `EN` and `en` in one object.
- English is optional. Display selection tries the exact locale, language-script when both script and region were requested, language, `en`, then the lexicographically first normalized tag.

Descriptions contain Markdown source with at most **4000 user-perceived Unicode characters (extended grapheme clusters) per locale**, inclusive. Source text is preserved; Markdown syntax is not validated. Use simple text and emphasis: raw HTML, images, and interactive content are unsupported, and links are not opened.

Setting and option labels do not have the description-specific 4000-character limit; the total manifest file-size limit still applies. These manifest rules are distinct from the [localized model limits](script.md#model-limits) of script return values.

## Permissions

Manifest v1 supports only `permissions.network`:

```json
{"permissions": {"network": {"hosts": ["api.example.com", "*.cdn.example.com"]}}}
```

`network` must be an object containing the required `hosts` array of strings. An omitted network permission or an empty host list requests no network access. Do not add storage, logger, or settings permission entries.

Host patterns:

- ASCII hostnames only; normalized to lowercase. Do not include a scheme, port, path, query, fragment, or user information.
- At most 253 characters excluding a leading `*.`. Each dot-separated label has 1–63 letters, digits, or interior hyphens; no empty labels, leading/trailing hyphens, or trailing dot.
- Only a single leading `*.` wildcard is allowed. `*.example.com` matches `cdn.example.com` and `a.cdn.example.com`, but not `example.com`.
- There is no allow-all pattern. Duplicate patterns after lowercase normalization are errors; `example.com` and `*.example.com` are distinct and may both appear.
- Hostname syntax does not establish reachability or authorize private/local addresses. Runtime HTTP restrictions apply separately.

**A declaration requests access; it does not grant it.** Each request and redirect must match both manifest hosts and the installation's approved hosts. Request only domains the plugin actually contacts. See [HTTP permissions and redirects](script.md#urls-permissions-and-headers).

## Settings

Settings are static user configuration, not the dynamic [search filter schema](script.md#search). The application can display them without running the script. Their effective values are read through `context.settings`.

Every setting accepts these common fields:

| Field | JSON type | Required | If omitted / rule |
| --- | --- | --- | --- |
| `id` | string | Yes | Nonblank identifier used in the script. |
| `type` | string | Yes | `text`, `secret`, `boolean`, `num`, `select`, or `multiSelect`. |
| `label` | localized text | Yes | User-facing label. |
| `description` | localized Markdown text | No | No description. |
| `required` | boolean | No | `false`. |

Setting IDs are unique within the manifest. IDs and option values are compared exactly and case-sensitively; whitespace is not trimmed from stored values.

### Setting types and defaults

| Type | Value type | `defaultValue` | Script read type |
| --- | --- | --- | --- |
| `text` | string | Optional; no default when omitted. Empty string is valid. | `String` |
| `secret` | sensitive string | **Forbidden**, even `null` or an empty string. | `String` |
| `boolean` | boolean | Optional; defaults to `false`. | `bool` |
| `num` | finite number | Optional; no default. Integers and fractions accepted. | `num` |
| `select` | one option value string | Optional; must match a declared option exactly. | `String` |
| `multiSelect` | array of option value strings | Optional; every value must be declared, without duplicates. An empty array is valid. | `List<String>` |

`options` is required only for `select` and `multiSelect` and is invalid on every other type. A secret setting has no hardcoded default: the user supplies its value. Do not put tokens, passwords, or private signing keys in the manifest or script.

### Options

`select` and `multiSelect` require a nonempty `options` list. Each object contains exactly:

| Field | JSON type | Required | Rule |
| --- | --- | --- | --- |
| `value` | string | Yes | Nonblank, unique within this setting. This is the stored value. |
| `label` | localized text | Yes | Display label. |

A label is not the stored value. Changing a label does not require changing its stable option value.

### Required values and script access

`required: true` does not require a manifest default. A valid effective value must be available before invocation; a valid default can satisfy this requirement. `false`, `0`, `""`, and `[]` are values, not absence. A required secret needs a supplied value because it cannot declare a default.

An unset optional value without a default is read as `null`. Read settings by ID using the exact type from the table, for example:

```dart
final token = await context.settings.get<String>('apiToken');
final minimum = await context.settings.get<num>('minimumRating');
```

See [script settings](script.md#settings) for snapshot behavior and errors. After changing the manifest, regenerate the plugin's [signature](README.md#signing).

[Back to contents](#contents) · [Plugin authoring](README.md) · [Dart script reference](script.md)
