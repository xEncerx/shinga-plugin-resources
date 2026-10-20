> Created: `2026-10-15T17:24:20Z` (UTC).

# Dart Plugin Script — API v1

[Plugin authoring](README.md) · [Manifest reference](manifest.md)

A source plugin translates a site's API or text responses into Shinga models. Write one Dart entry file using the SDK below; Shinga supplies `context` and calls the provider methods. You do not write a dispatcher, JSON envelope, or `main()`.

## Contents

1. [Script structure](#script-structure)
2. [Provider methods](#provider-methods)
3. [IDs and localized text](#ids-and-localized-text)
4. [Title and home models](#title-and-home-models)
5. [Search](#search)
   - [Schema and fields](#schema-and-fields)
   - [Selected values](#selected-values)
   - [Validation and typed reads](#validation-and-typed-reads)
   - [Sorting](#sorting)
   - [Requests and pagination](#requests-and-pagination)
6. [Context](#context)
   - [Settings](#settings)
   - [Storage](#storage)
   - [Logging](#logging)
   - [Runtime information](#runtime-information)
7. [HTTP](#http)
   - [Request API](#request-api)
   - [Bodies and responses](#bodies-and-responses)
   - [URLs, permissions, and headers](#urls-permissions-and-headers)
   - [Redirects and cookies](#redirects-and-cookies)
8. [Errors](#errors)
9. [Limits](#limits)
10. [Complete script example](#complete-script-example)

## Script structure

Import the SDK exactly once, without a prefix, `show`, or `hide`:

```dart
import 'package:shinga_plugin_sdk/shinga_plugin_sdk.dart';
```

The provider declaration must be exactly this form:

```dart
final class SourceProvider extends SourceProviderBase {
  // Implement the required methods listed below.
}
```

The declaration above illustrates the class shape, not a complete plugin. A [complete implementation](#complete-script-example) is provided at the end.

Rules:

- `SourceProvider` is the only public top-level declaration. Do not add `main()`.
- Use an implicit constructor or one unnamed, non-factory constructor with no parameters.
- No `abstract`, `with`, or `implements` on the provider. Do not override `context` or names beginning with `$`.
- Provider fields and additional helper methods must have private names beginning with `_`.
- Private top-level functions, classes, enums, and named extensions may hold helpers. Do not add top-level variables, even private `const` or `final` variables. Put constants in private class fields instead.
- Do not subclass or implement the SDK's closed model types; construct the supplied variants.
- Keep all author code in the entry file. Local imports, additional packages, `part`, `export`, `library`, deferred imports, and conditional imports are not supported.

Other allowed imports are `dart:async`, `dart:collection`, `dart:convert`, and `dart:math`. These may use prefixes or import combinators. There is no `dart:io`, Flutter, filesystem, socket, WebView, or direct database API. Use `context.http` and `context.storage` instead. There is no built-in HTML DOM parser.

The entry path must end in lowercase `.dart`. Save the file as UTF-8, without a BOM or NUL characters. See [limits](#limits) for source size and execution budgets.

### Invocation lifetime

Each invocation creates a fresh provider and calls one method. Fields, static caches, and constructor side effects do not persist between invocations. There are no initialization or disposal hooks, and `getSearchSchema()` is not automatically called before `search()`.

Use storage for persistent data and continuation for pagination state. `await` asynchronous work needed by the result; background work is not guaranteed to finish after the method returns. Methods must return their exact `Future<...>` types; `async` is optional, but generators are not supported.

The script runs in a restricted interpreter, not a full Dart VM environment. Accepted imports do not make arbitrary Dart packages or every VM-specific behavior available.

## Provider methods

Use explicit, unprefixed types and the exact positional parameters shown here. Do not make contract methods static, generic, nullable, getters, or setters.

| Signature | Required | Contract |
| --- | --- | --- |
| `Future<SourceSearchSchema> getSearchSchema()` | Yes | Return ordered local filter fields and supported sorts. An empty schema is valid for query-only sources. |
| `Future<SourceSearchResult> search(SourceSearchRequest request)` | Yes | Return one page of previews for explicit query, selections, sort, and continuation. |
| `Future<SourceTitleDetails> getTitle(SourceTitleId id)` | Yes | Load full metadata using a stable source-local title ID. |
| `Future<SourceHome> getHome()` | No | Return ordered home sections. |
| `Future<Uri> getInitialReadUrl(SourceTitleId id)` | No | Return an absolute HTTP(S) URL from which reading starts. This is not an API for chapter lists or page images. |

Omit an unsupported optional method: its inherited implementation throws `SourceUnsupportedException`. All successful return values are non-null. An empty result is not a substitute for an unsupported operation or a failed request.

## IDs and localized text

### IDs

`SourceTitleId(String value)` wraps a stable site identifier, such as a slug or numeric ID encoded as a string. Read it through `.value`; it is not necessarily a URL. Preserve the same ID across search, home, and details. Encode it with `Uri.encodeComponent` when inserting it into a URL path.

IDs must be nonblank; they are not automatically trimmed or normalized. Compare title IDs by `id.value`, not by wrapper object identity.

| ID | Unique within |
| --- | --- |
| Title ID | One search page or one home section; the same title may appear in different home sections. |
| Search section ID | The schema. |
| Search field ID | The entire schema, across all sections. |
| Choice option ID | Its field. |
| Sort ID | The schema. |
| Home section ID | The home result. |

Except for `SourceTitleId`, these IDs are plain strings. Option IDs are source-local identifiers, not display labels or automatically translated site parameters.

### LocalizedText and LocaleTag

```dart
final english = LocaleTag.tryParse('en')!;
final title = LocalizedText({english: 'Example title'});
final displayed = title.resolve(english);
```

- `LocaleTag.tryParse(String)` returns `null` for an invalid tag. Supported syntax is `language[-Script][-REGION]`: 2–8 ASCII language letters, optional four-letter script, optional two-letter or three-digit region.
- Tags normalize language to lowercase, script to title case, and alphabetic region to uppercase. Underscores, variants, and extensions are not supported. `.value` returns the normalized tag; `.language`, `.script`, and `.region` expose its parts.
- `LocalizedText(Map<LocaleTag, String>)` requires a nonempty map of nonblank strings. It preserves the supplied text and exposes an immutable `.values` map.
- `resolve(locale)` tries the exact tag, language-script when both script and region were requested, language, `en`, then the first lexicographically sorted available tag. It does not translate text.

Use only translations actually supplied by the source or by your plugin. All supplied locales count toward [model limits](#model-limits), not only the displayed locale.

## Title and home models

Constructor parameters below become read-only fields with the same names. Model collections are immutable snapshots, including nested alternative-name lists. Construct new models rather than mutating returned collections.

### Covers and previews

```dart
SourceCover({Uri? originalUrl, Uri? thumbnailUrl});

SourceTitlePreview({
  required SourceTitleId id,
  required LocalizedText title,
  required SourceCover? cover,
  LocalizedText? status,
});
```

`cover` is required but nullable: pass `cover: null` when unavailable. A `SourceCover` may contain either URL, both, or neither. Cover URLs and initial reader URLs must be absolute HTTP(S) URLs with a host. Return absolute URLs even when the site's response contains relative paths.

`status` is a localized label owned by the source, not an application enum.

### Full title details

```dart
SourceTitleDetails({
  required SourceTitleId id,
  required LocalizedText title,
  required SourceCover? cover,
  LocalizedText? status,
  LocalizedText? type,
  Map<LocaleTag, List<String>> altNames = const {},
  int? chapters,
  int? views,
  int? volumes,
  int? favorites,
  double? rating,
  int? scoredBy,
  DateTime? releasedAt,
  DateTime? endedAt,
  List<LocalizedText> genres = const [],
  List<LocalizedText> categories = const [],
  List<String> authors = const [],
  LocalizedText? description,
});
```

| Fields | Rules |
| --- | --- |
| `status`, `type` | Source-owned localized labels. Omit unknown values rather than inventing a status or type. |
| `genres`, `categories` | Ordered localized labels, not search option IDs. Order and repeated labels are preserved. |
| `altNames` | Names grouped by locale; each locale's list must contain unique, nonblank strings. |
| `authors` | Ordered, unique, nonblank plain strings. |
| `chapters`, `views`, `volumes`, `favorites`, `scoredBy` | Nonnegative safe integers, or `null` when unknown. Zero is a known value. |
| `rating` | A finite `double`, or `null`. API v1 does not impose a rating scale or require a vote count. |
| `releasedAt`, `endedAt` | Optional dates; serialized as UTC. Supply dates actually known by the source. |
| `description` | Optional localized text; it has a larger per-locale size budget than ordinary labels. |

For a sparse response, `id`, `title`, and `cover: null` are sufficient. Missing optional metadata is not an error. Avoid returning raw markup or fabricated values when the source has no usable text.

### Home

```dart
SourceHome(List<SourceHomeSection> sections);

SourceHomeSection({
  required String id,
  required LocalizedText title,
  required SourceHomeSectionKind kind,
  required SourceHomeSectionLayout layout,
  required List<SourceTitlePreview> items,
});
```

- Section kinds: `recommended`, `latest`, `popular`, `trending`, `custom`. Use `custom` for source-specific sections.
- Layouts: `carousel`, `grid`.
- Sections and items retain their supplied order. Empty home results and empty sections are valid.
- `SourceHomeSectionKind`, `SourceHomeSectionLayout`, `SourceSortDirection`, `PositiveMatchMode`, and `SearchSectionKind` expose `.id` and `fromId(String)`; unknown IDs return `null`.

## Search

Search declarations describe supported filters; requests contain explicit selections. The provider translates those selections into the site's parameters. Shinga does not infer the site's query syntax from field IDs.

### Schema and fields

```dart
SourceSearchSchema({
  List<SearchSection> sections = const [],
  List<SortDefinition> sorts = const [],
});

SearchSection({
  required String id,
  required LocalizedText label,
  required SearchSectionKind kind,
  List<SearchField> fields = const [],
});
```

Sections and fields are ordered. `SearchSectionKind.basic` and `.advanced` classify fields; they do not choose widgets. Empty schemas and sections are valid. Field IDs must be unique across all sections.

Every concrete field requires `String id` and `LocalizedText label`. Its optional `defaultValue` has the matching value type below; the default is `null`.

| Field class | Additional constructor parameters | Value type |
| --- | --- | --- |
| `TextField` | `TextValue? defaultValue` | `TextValue` |
| `NumberField` | `num? min`, `num? max`, `bool integerOnly = false`, `NumberValue? defaultValue` | `NumberValue` |
| `BooleanField` | `BooleanValue? defaultValue` | `BooleanValue` |
| `SingleChoiceField` | Required `List<ChoiceOption> options`, `SingleChoiceValue? defaultValue` | `SingleChoiceValue` |
| `MultiChoiceField` | Required `List<ChoiceOption> options`, required `PositiveMatchMode defaultPositiveMode`, `List<PositiveMatchMode>? positiveModes`, `bool allowExclusion = false`, `MultiChoiceValue? defaultValue` | `MultiChoiceValue` |
| `RangeField` | `num? min`, `num? max`, `bool integerOnly = false`, `RangeValue? defaultValue` | `RangeValue` |

All parameters are named. Choice options use:

```dart
ChoiceOption({required String id, required LocalizedText label});
```

Declaration rules:

- Choice fields need a nonempty option list with unique IDs within that field. Equal labels are allowed.
- Numeric bounds are independently optional and inclusive. If both exist, `min <= max`. Values must be finite; integral numbers must fit the safe-integer range. `integerOnly` rejects fractional bounds and selections without rounding.
- `positiveModes` defaults to `[defaultPositiveMode]`. An explicit list must be nonempty, unique, and include that default. Supported modes are `PositiveMatchMode.any` and `.all`.
- `allowExclusion` must be enabled before accepting negative choices. Implement every advertised exclusion; never silently ignore it.
- Defaults must satisfy the declaration. A multi-choice default must use `defaultPositiveMode`.

**Defaults initialize the local form; they are not implicit search constraints.** An absent request entry stays unset, and query-only search must not apply field or sort defaults.

A declaration and typed read can share the same field instance:

```dart
final year = NumberField(
  id: 'year',
  label: LocalizedText({LocaleTag.tryParse('en')!: 'Release year'}),
  min: 1900,
  integerOnly: true,
);
final schema = SourceSearchSchema(
  sections: [
    SearchSection(
      id: 'main',
      label: LocalizedText({LocaleTag.tryParse('en')!: 'Filters'}),
      kind: SearchSectionKind.basic,
      fields: [year],
    ),
  ],
);
final request = SourceSearchRequest(values: {'year': NumberValue(2020)});
SearchSchemaValidator.validateRequest(schema, request);
final selectedYear = year.read(request)?.value; // 2020; null when unset.
```

Keep shared declarations in private provider fields or a private helper object, not top-level variables.

### Selected values

```dart
const TextValue(String value);
NumberValue(num value);
const BooleanValue(bool value);
SingleChoiceValue(String optionId);
MultiChoiceValue({
  required PositiveMatchMode positiveMode,
  List<String> included = const [],
  List<String> excluded = const [],
});
RangeValue({num? min, num? max});
```

- Missing map entry means unset. `BooleanValue(false)`, `NumberValue(0)`, and `TextValue('')` are explicit selections.
- A `TextValue` may contain empty or whitespace text. This differs from `SourceSearchRequest.query`, which must be nonblank when supplied.
- `SingleChoiceValue.optionId` must identify an option of that field.
- Multi-choice `.included` and `.excluded` contain unique, disjoint IDs. `any` requires at least one included option to match; `all` requires every included option. An empty included list adds no positive constraint. Exclusions forbid matches independently of the positive mode.
- `RangeValue` requires at least one endpoint. Endpoints are inclusive; `RangeValue(max: 2020)` has no lower constraint. Do not substitute declaration bounds for missing selected endpoints.

### Validation and typed reads

```dart
SearchSchemaValidator.validateRequest(schema, request);
SearchSchemaValidator.validateValue(field, value);
```

Both are `static void` methods. `validateRequest` checks all active fields and the selected sort against the supplied schema. It does not fetch a schema, interpret continuation, or apply defaults.

Each concrete field has a typed `read(SourceSearchRequest request)` returning its value type or `null`. For example, `RangeField.read` returns `RangeValue?`. It validates only that field's explicit selection, not other fields or sorting.

Handle unsupported active selections separately from broken declarations:

```dart
try {
  SearchSchemaValidator.validateRequest(schema, request);
} on SearchSelectionException {
  throw const SourceInvalidRequestException();
}
```

`SearchSelectionException` exposes `.reason` and optional `.fieldId`, `.optionId`, `.sortId`. Reasons are `unknownField`, `wrongType`, `outOfBounds`, `textTooLong`, `unknownOption`, `exclusionDisabled`, `unsupportedPositiveMode`, `unknownSort`, and `unsupportedDirection`.

Invalid declarations, duplicate IDs, or invalid defaults throw `ArgumentError`. Fix the declaration; do not turn that programming error into an invalid user request.

### Sorting

```dart
SortDefinition({
  required String id,
  required LocalizedText label,
  required List<SourceSortDirection> directions,
});

SourceSortSelection({
  required String id,
  required SourceSortDirection direction,
});
```

Each sort supports one or both unique directions: `SourceSortDirection.ascending` and `.descending`. The request must explicitly select a declared sort and a supported direction. There is no schema-level default sort or implicit direction. Translate the selected ID and direction into the site's syntax yourself.

### Requests and pagination

```dart
SourceSearchRequest({
  String? query,
  Map<String, SearchValue> values = const {},
  SourceSortSelection? sort,
  Object? continuation,
});

SourceSearchResult({
  required List<SourceTitlePreview> items,
  Object? nextContinuation,
});
```

- `query == null` means no query. A supplied query must be nonblank.
- `.values` contains only explicit selections, keyed by field ID. Empty values and absent sort are valid even when a schema declares defaults.
- `.items` is one ordered page. IDs must be unique within the page. An empty page is valid.
- `.nextContinuation == null` ends pagination. Any non-null JSON value, including `0`, `false`, or `''`, is continuation state.
- Continuation is opaque to Shinga. Use a page number, a cursor, or a small map containing the site-specific state needed for the next page. Validate its expected shape before using it.
- Continue the same query, selections, and sort. Any change starts a new flow with `continuation: null`.
- Do not store secrets or unnecessary response data in continuation, and do not blindly follow a remote pagination URL. Prefer your own page/cursor representation and known API endpoints.

Continuation and storage values use bounded JSON-compatible data: `null`, strings, booleans, safe integers, finite doubles, lists, and maps with string keys. They cannot contain `Uri`, `DateTime`, SDK model objects, cycles, or arbitrary Dart instances. Continuation is captured as a deep immutable snapshot.

## Context

The inherited read-only `context` exposes:

| Property | Type | Purpose |
| --- | --- | --- |
| `settings` | `SourceSettings` | Read effective manifest settings for this invocation. |
| `storage` | `SourceStorage` | Persistent key/value data scoped to this installation. |
| `http` | `SourceHttp` | Authorized HTTP requests. |
| `logger` | `SourceLogger` | Best-effort diagnostic logs. |
| `runtimeInfo` | `SourceRuntimeInfo` | Platform, application locale, and supported capabilities. |

Do not construct, attach, replace, or pass a context parameter to provider methods.

### Settings

```dart
Future<T?> get<T extends Object>(String id);
```

Call `context.settings.get<T>(id)` with the exact type matching the [manifest setting](manifest.md#settings):

| Manifest type | Dart type |
| --- | --- |
| `text`, `secret`, `select` | `String` |
| `boolean` | `bool` |
| `num` | `num`, not `int` or `double` |
| `multiSelect` | `List<String>` |

```dart
final token = await context.settings.get<String>('apiToken');
```

This reads the effective user value or declared default. An unset optional setting returns `null`; required settings must be available before the method can run. Settings are a snapshot: changes during a running method do not alter that invocation. There is no settings write API.

Multi-select results are immutable. Secrets are returned to the plugin as plaintext strings; never log them. Unknown IDs or wrong requested types produce [settings errors](#capability-errors), even if a value is unset.

### Storage

```dart
Future<JsonValue> get(String key);
Future<void> set(String key, Object value);
Future<bool> remove(String key);
Future<bool> has(String key);
Future<void> batch(List<StorageOperation> operations);

const factory StorageOperation.set(String key, Object value);
const factory StorageOperation.remove(String key);
```

These are methods of `context.storage`. `JsonValue` denotes JSON-compatible data and may be `null`.

- `get` returns `null` for a missing key. `has` tests existence; `remove` returns whether the key existed.
- `set` atomically replaces a value. Its top-level value cannot be `null`; nested JSON nulls are allowed. Use `remove` to delete a key.
- `batch` applies operations in order, all or none. Repeated keys are allowed; later operations see earlier ones. Storage quota is checked against the final state.
- Separate `get` and `set` calls are not an atomic read-modify-write transaction. There is no key enumeration, `clear`, compare-and-set, or transaction callback.
- Cancellation can stop delivery of a result after a write has begun committing; it does not guarantee that committed data was rolled back.

```dart
await context.storage.batch([
  StorageOperation.set('catalog-cache', {
    'savedAt': DateTime.now().toUtc().toIso8601String(),
    'ids': ['title-a', 'title-b'],
  }),
  const StorageOperation.remove('old-cache'),
]);
```

Storage persists across invocations of this installation, unlike provider fields. It is not a secret-settings vault. Apply your own cache expiration and avoid storing credentials unnecessarily.

### Logging

```dart
void debug(String message, [Map<String, JsonValue>? details]);
void info(String message, [Map<String, JsonValue>? details]);
void warn(String message, [Map<String, JsonValue>? details]);
void error(String message, [Map<String, JsonValue>? details]);
```

Use `context.logger`, not `print`. `print` output is suppressed. Details must be JSON-compatible.

```dart
context.logger.warn('Title endpoint rate limited', {'status': 429});
```

Logs are best effort: invalid or excess entries may be dropped, old entries are evicted, and logs do not survive application shutdown. There is no delivery acknowledgement or flush API.

Known secret-setting values are redacted, but this is not a general credential detector. Do not log tokens, cookies, authorization headers, complete URLs with sensitive query strings, or raw response bodies. Tokens obtained from HTTP or storage are not necessarily known to the redactor. Prefer endpoint templates and safe status/error codes.

### Runtime information

```dart
final String platform;
final LocaleTag locale;
final Set<String> capabilities;
```

Read these through `context.runtimeInfo`. Locale is the effective application locale for the invocation. Capabilities are an immutable set of supported API features: `settings.read`, `storage`, `http`, `logger`, and `runtime.info`.

Capability support is not permission approval: `http` does not mean a particular domain is allowed. There is no API to change runtime information or enumerate approved network hosts. `platform` is a string, not a public enum.

## HTTP

### Request API

```dart
SourceHttp withDefaults({required Map<String, String> headers});

Future<SourceHttpResponse> request({
  required String method,
  required Uri url,
  required SourceHttpResponseKind responseKind,
  bool followRedirects = true,
  List<SourceHttpField> query = const [],
  Map<String, String> headers = const {},
  SourceHttpBody? body,
  Duration? timeout,
});

const SourceHttpField(String name, String value);
```

Use `context.http` or a client returned by `withDefaults`:

```dart
final client = context.http.withDefaults(headers: {'Accept': 'application/json'});
final response = await client.request(
  method: 'GET',
  url: Uri.parse('https://api.example.com/titles'),
  query: [
    const SourceHttpField('tag', 'action'),
    const SourceHttpField('tag', 'comedy'),
  ],
  responseKind: SourceHttpResponseKind.json,
  timeout: const Duration(seconds: 15),
);
```

Methods must be uppercase HTTP tokens, such as `GET`, `POST`, or `QUERY`; there is no fixed GET/POST-only list. Invalid methods and nonpositive timeouts are rejected. An omitted timeout adds no smaller request-specific deadline; the invocation deadline still applies. A supplied timeout covers the request including redirects.

Query fields are appended after any existing URL query, retain their order, and preserve repeated names. Pass unencoded names and values. Request headers and query collections are captured before asynchronous dispatch.

### Bodies and responses

| Request body | Encoding | Default content type when absent |
| --- | --- | --- |
| `SourceHttpBody.text(String value)` | UTF-8 | `text/plain; charset=utf-8` |
| `SourceHttpBody.json(Object? value)` | JSON, including JSON null | `application/json; charset=utf-8` |
| `SourceHttpBody.form(List<SourceHttpField> fields)` | URL-encoded ordered fields, preserving repeated names | `application/x-www-form-urlencoded; charset=utf-8` |

The corresponding concrete body classes are `SourceHttpTextBody`, `SourceHttpJsonBody`, and `SourceHttpFormBody`. JSON and form input are captured so later mutation cannot change the request. There are no raw-binary, file, multipart, or streaming request bodies.

`SourceHttpResponse` exposes:

| Field | Type | Meaning |
| --- | --- | --- |
| `status` | `int` | HTTP status, including ordinary 4xx and 5xx responses. |
| `finalUrl` | `Uri` | Accepted final URL, including appended query and followed redirects. |
| `headers` | `Map<String, List<String>>` | Immutable lowercase names with repeated values preserved. |
| `body` | `SourceHttpResponseBody` | Body variant selected only by `responseKind`. |

| `responseKind` | Body class | `.value` |
| --- | --- | --- |
| `SourceHttpResponseKind.text` | `SourceHttpTextResponse` | Strict UTF-8 `String`. |
| `SourceHttpResponseKind.json` | `SourceHttpJsonResponse` | Deeply immutable JSON-compatible `Object?`, including null. |
| `SourceHttpResponseKind.bytes` | `SourceHttpBytesResponse` | Immutable `List<int>` after decompression. |

```dart
final data = (response.body as SourceHttpJsonResponse).value;
```

Guard JSON objects with `value is Map<Object?, Object?>` before indexing them. Use the guarded map directly: calling `.cast()` on immutable HTTP response maps is not supported by the interpreter.

`Content-Type` does not choose decoding. Supported content encodings are identity, gzip, and deflate; Brotli and encoding chains are not supported. Text is strict UTF-8, not charset-sniffed.

**Check HTTP status yourself.** A 404 or 500 is not automatically a `SourceHttpException`. However, decoding happens before a response is delivered: HTML returned to a JSON request, malformed JSON, or an empty JSON body (including an empty 204) produces `http.decode_failed`. If status must be inspected independently of JSON parsing, request text or bytes and decode after checking the status.

There is no automatic retry, response cache, cookie jar, authentication challenge handling, WebSocket, or streaming API.

### URLs, permissions, and headers

- Requests require absolute HTTP(S) URLs with a host, no user information, and a valid port. Fragments are removed. Hostnames must be ASCII without a trailing dot; use ASCII/Punycode form where necessary.
- Every destination, including redirects, must match both requested manifest hosts and currently approved hosts. `*.example.com` does not match `example.com`.
- Direct requests to nonpublic destinations are rejected; this includes DNS results containing a forbidden address. Device proxy configuration is controlled by the application, not by the plugin.
- Header precedence is application defaults → local `withDefaults` → request headers. Overrides are case-insensitive. `withDefaults` returns a new immutable client without changing the original.
- `Authorization` and `Cookie` are allowed. Among control characters, only TAB is permitted in header values; DEL and characters above byte value 255 are rejected.

Forbidden header names, case-insensitively:

```text
host, content-length, connection, keep-alive, transfer-encoding,
te, trailer, upgrade, expect, proxy-authorization,
proxy-connection, proxy-authenticate, and every proxy-* name
```

### Redirects and cookies

With `followRedirects: true`, HTTP follows 301, 302, 303, 307, and 308, up to [the redirect limit](#http-and-storage-limits). A redirect needs one nonempty `Location`; relative locations are supported.

- 303 changes non-HEAD methods to GET. 301/302 change POST to GET. Other combinations preserve method and body.
- A change to GET removes the body and `content-*` headers.
- A change of scheme, host, or port removes credentials and most custom headers. Local defaults are not reapplied after removal.
- Only these headers may survive an origin change: `accept`, `accept-charset`, `accept-language`, `accept-encoding`, `user-agent`, `content-type`, `content-encoding`, `content-language`, `content-location`, `cache-control`, `pragma`, `if-match`, `if-none-match`, `if-modified-since`, `if-unmodified-since`, `if-range`, `range`, `referer`, and `origin`.
- Every hop is authorized independently. Intermediate response bodies also count toward decoding and response-size checks.

With `followRedirects: false`, `Location` is not interpreted: the normal status, headers, and decoded body are returned. A manual follow-up is a separate authorized request.

Cookies are entirely manual. Read individual `Set-Cookie` values from `response.headers['set-cookie']`, select cookies appropriate to the destination, and explicitly send a `Cookie` header. The host neither stores cookies nor applies response cookies to a subsequent request or redirect. Do not forward credentials to an unrelated origin.

## Errors

### Provider outcomes

All five exceptions have a `const` zero-argument constructor. They do not carry messages, causes, or retry-after fields.

| Throw | Meaning | Reported code |
| --- | --- | --- |
| `SourceUnsupportedException()` | Optional operation is not supported. | `source.unsupported` |
| `SourceNotFoundException()` | The requested source resource does not exist. | `source.not_found` |
| `SourceInvalidRequestException()` | An otherwise well-formed request has unsupported selections or semantics. | `source.invalid_request` |
| `SourceTemporarilyUnavailableException()` | The source is temporarily unavailable. | `source.temporarily_unavailable` |
| `SourceRateLimitedException()` | The source is rate limiting requests. | `source.rate_limited` |

Use source-specific evidence when mapping HTTP statuses. For example, 404 from a title endpoint may mean a missing title, while 404 from a catalog endpoint may indicate a broken integration. Do not convert every error into an empty successful result.

### Capability errors

These exceptions expose a safe `.code`; do not parse exception messages.

| Exception | Codes |
| --- | --- |
| `SourceSettingsException` | `settings.unknown_id`, `settings.invalid_type` |
| `SourceStorageException` | `storage.invalid_key`, `storage.invalid_value`, `storage.quota_exceeded`, `storage.commit_failed`, `capability.denied` |
| `SourceHttpException` | See below. |

Settings/storage exceptions accept a code through their constructor; normally catch exceptions produced by `context`, rather than manufacturing them. `SourceHttpException(String code)` accepts only the closed set below.

| HTTP code | Meaning |
| --- | --- |
| `http.invalid_request` | Invalid method, URL, body, timeout, or request payload. |
| `http.invalid_headers` | Invalid, forbidden, or oversized request headers. |
| `http.denied` | Requested and approved hosts do not both authorize the destination. |
| `http.unsafe_address` | Forbidden direct destination address. |
| `http.stopped` | The operation's authority or lifetime has stopped. |
| `http.cancelled` | Request cancelled. |
| `http.timeout` | Request-specific timeout expired. |
| `http.resource_limit` | HTTP capacity exhausted. |
| `http.response_too_large` | Response body or headers exceeded their budget. |
| `http.decode_failed` | Unsupported encoding, invalid UTF-8/JSON, or excessive JSON structure. |
| `http.redirect_failed` | Invalid Location or redirect limit exceeded. |
| `http.transport_failed` | Other transport failure, without native diagnostics. |

A transport failure or timeout may reasonably map to source unavailability. Invalid headers, permissions, or oversized payloads usually need a different response; do not hide all HTTP failures under a generic outage or retry loop.

### Author errors and terminal failures

| Situation | Result |
| --- | --- |
| Invalid constructor data, schema declarations, defaults, or duplicate IDs | Usually `ArgumentError`: fix the plugin. Some result rules are checked only when the result leaves the method. |
| `SearchSelectionException` left uncaught | Generic plugin failure, not automatic `source.invalid_request`. Map it explicitly when appropriate. |
| Other uncaught provider-method exception | `plugin.exception`; arbitrary exception details are not returned as a public payload. |
| Invalid or oversized API input/result | `api.params_invalid` / `api.result_invalid`; the invocation fails. |
| Malformed or oversized aggregate host call | `host_call.payload_invalid`; not guaranteed to be a catchable capability exception. |
| Too many total or concurrent storage/HTTP calls | `host_call.protocol_invalid`; not `http.resource_limit`. |
| Interpreter step limit | `execution.step_limit`; not a source exception the plugin should simulate. |
| Interpreter timeout / absolute invocation deadline | `execution.d4rt_timeout` / `invocation.hard_timeout`; the invocation cannot continue. |

Use narrow catches. In interpreted code, when handling a Dart library parsing error, a general catch followed by `if (error is FormatException)` is safer than relying on a typed catch to recognize every native parsing failure. Rethrow unrelated errors; never treat all programming errors as an unavailable source.

## Limits

Ceilings are inclusive. `KiB` means 1024 bytes; string limits use UTF-8 bytes, not Dart `.length`. Serialized JSON includes quotes and escaping. Per-field maxima do not override total byte, node, or nesting budgets.

### Model limits

| Item | Maximum |
| --- | ---: |
| Serialized API request | 260876 bytes |
| Serialized API result | 262121 bytes |
| Payload container depth, root at zero | 31 |
| Aggregate JSON nodes | 10000 |
| Entries in a generic list/map | 1000 |
| Generic JSON string or object key | 64 KiB |
| Integer magnitude | 9007199254740991 |
| Search/section/field/option/sort/home-section ID | 128 bytes |
| Title ID | 1024 bytes |
| Cover or reader URL | 4096 bytes |
| Locales in one localized field or alternative-name map | 32 |
| Ordinary localized value / author name / alternative name | 4096 bytes |
| Description value, per locale | 64 KiB |
| Search results per page | 100 |
| Home sections / items per section | 32 / 100 |
| Alternative names per locale / authors | 64 / 64 |
| Genres / categories in title details | 1000 each |
| Search sections / fields across all sections | 64 / 64 |
| Explicit selected fields | 64 |
| Choice options per field | 1000 |
| Included + excluded IDs in one selection | 1000 |
| Query / selected text | 4096 bytes |
| Sort declarations | 1000 |
| Each serialized continuation | 16 KiB |

Constructor validation is not the entire result check. A model may construct successfully and still fail serialization because of text size, aggregate size, nesting, or integer limits. Keep results compact and paginate rather than returning the entire catalog.

The Dart entry source is limited to 256 KiB of UTF-8 bytes; the application may choose a smaller limit.

### HTTP and storage limits

| Item | Maximum |
| --- | ---: |
| Storage key | 128 bytes, nonempty |
| Serialized storage value | 32 KiB |
| Storage batch operations | 64 |
| Stored keys per installation | 1024 |
| Stored key bytes + encoded value bytes per installation | 1 MiB |
| Aggregate storage/HTTP call payload including framing | 256 KiB |
| Pending storage + HTTP calls per invocation | 16 |
| Total storage + HTTP calls per invocation | 256 |
| HTTP response compressed / decompressed body | 8 MiB each |
| Request / response headers | 64 KiB each |
| HTTP JSON nodes / container depth | 100000 / 32 |
| Followed redirects | 5 |
| Log message | 2048 bytes |
| Log entry | 8 KiB |
| Submitted log entries per invocation | 100 |

Storage and request payloads also obey the generic JSON limits. Enclosing structures consume nesting budget. A batch of 64 individually valid 32 KiB values cannot fit the aggregate call budget. HTTP request bodies are constrained by the call payload, not the 8 MiB response allowance. Header accounting includes application-supplied headers, so leave headroom.

Logs are retained only within bounded in-memory storage: up to 256 entries and 1 MiB per installation, with an 8 MiB global budget. These are retention limits, not delivery guarantees.

### Execution limits

The application chooses budgets; a script or manifest cannot increase them. The default interpreter budget is 100000 steps and 120 seconds, with an absolute invocation deadline of 125 seconds. The application may use smaller budgets; the step ceiling configurable by the host is 10000000. A request's explicit timeout may shorten its wait but cannot extend invocation lifetime.

## Complete script example

This example defines a small query-only adapter for a hypothetical API:

- `GET /titles?q=...&page=N` returns `{"items":[{"id":"a","name":"Title"}],"hasMore":false}`.
- `GET /titles/{id}` returns `{"id":"a","name":"Title"}`; 404 means a missing title.
- IDs and names are nonblank strings; previews within a page have unique IDs.

Declare `api.example.com` in the manifest and set `entry` to this script's path. Replace the endpoints and response mapping with the actual site's contract. The example implements every required method; optional home and reader operations remain unsupported.

```dart
import 'package:shinga_plugin_sdk/shinga_plugin_sdk.dart';

final class SourceProvider extends SourceProviderBase {
  final _schema = SourceSearchSchema();

  @override
  Future<SourceSearchSchema> getSearchSchema() async => _schema;

  @override
  Future<SourceSearchResult> search(SourceSearchRequest request) async {
    try {
      SearchSchemaValidator.validateRequest(_schema, request);
    } on SearchSelectionException {
      throw const SourceInvalidRequestException();
    }
    final cursor = request.continuation;
    if (cursor != null && (cursor is! int || cursor < 1)) {
      throw const SourceInvalidRequestException();
    }
    final page = cursor as int? ?? 1;
    final data = await _getJson(
      '/titles',
      query: [
        if (request.query != null) SourceHttpField('q', request.query!),
        SourceHttpField('page', '$page'),
      ],
    );
    final rows = data['items'];
    final more = data['hasMore'];
    if (rows is! List || more is! bool) {
      throw const SourceTemporarilyUnavailableException();
    }
    final items = <SourceTitlePreview>[];
    final ids = <String>{};
    for (final row in rows) {
      final item = _object(row);
      final id = _text(item['id']);
      if (!ids.add(id)) continue;
      items.add(SourceTitlePreview(
        id: SourceTitleId(id),
        title: _label(_text(item['name'])),
        cover: null,
      ));
    }
    return SourceSearchResult(
      items: items,
      nextContinuation: more ? page + 1 : null,
    );
  }

  @override
  Future<SourceTitleDetails> getTitle(SourceTitleId id) async {
    final data = await _getJson(
      '/titles/${Uri.encodeComponent(id.value)}',
      missingTitle: true,
    );
    return SourceTitleDetails(
      id: SourceTitleId(_text(data['id'])),
      title: _label(_text(data['name'])),
      cover: null,
    );
  }

  Future<Map<Object?, Object?>> _getJson(
    String path, {
    List<SourceHttpField> query = const [],
    bool missingTitle = false,
  }) async {
    final response = await context.http.request(
      method: 'GET',
      url: Uri.parse('https://api.example.com$path'),
      responseKind: SourceHttpResponseKind.json,
      query: query,
    );
    if (response.status == 404 && missingTitle) {
      throw const SourceNotFoundException();
    }
    if (response.status == 429) throw const SourceRateLimitedException();
    if (response.status < 200 || response.status >= 300) {
      throw const SourceTemporarilyUnavailableException();
    }
    return _object((response.body as SourceHttpJsonResponse).value);
  }

  Map<Object?, Object?> _object(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const SourceTemporarilyUnavailableException();
    }
    return value;
  }

  String _text(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const SourceTemporarilyUnavailableException();
    }
    return value;
  }

  LocalizedText _label(String value) =>
      LocalizedText({LocaleTag.tryParse('en')!: value});
}
```

This mapping assumes JSON error bodies too. If the actual site returns HTML or empty error bodies, use the status-first text/bytes approach described under [bodies and responses](#bodies-and-responses). Transport and decoding failures are deliberately not disguised as empty pages.

[Back to contents](#contents) · [Plugin authoring](README.md) · [Manifest reference](manifest.md)
