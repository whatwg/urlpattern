## Description

The `URLPattern` interface provides a web platform primitive for matching
URLs.  The pattern syntax is adopted from the popular [path-to-regexp][]
javascript library and is more ergonomic than using regular expressions.

### Normalization

When a URL is parsed it is automatically normalized to a canonical form. For
example, unicode characters are percent encoded in the `pathname` property, punycode
encoding is used in the hostname, default port numbers are elided, paths like
`/foo/./bar/` are collapsed to just `/foo/bar`, etc. In addition, there are some
pattern representations that parse to the same underlying meaning, like `foo` and
`{foo}`. Such cases are normalized to the simplest form. In this case `{foo}` gets
changed to `foo`.

## Constructor

Creates a new `URLPattern` object.  It has two forms.

**`new URLPattern(obj)`**

This form of the constructor takes a `URLPatternInit` dictionary object that
describes the URLs you want to match.  Its members can be any of `protocol`,
`username`, `password`, `hostname`, `port`, `pathname`, `search`, `hash`, or
`baseURL`.  If the `baseURL` property is provided it will be parsed as a URL
and used to populate any other properties that are missing.  If the `baseURL`
property is missing, then any other missing properties default to the pattern
`*` wildcard, accepting any input.

**`new URLPattern(pattern, baseURL)`**

This form of the constructor takes a URL string that contains patterns embedded
in it.  The URL string may be relative if a base URL is provided as the second
argument.  Note, it may be necessary to escape some characters in the URL
string where its ambiguous whether the character is separating different URL
components or if it's instead part of a pattern.  For example, you must write
`about\\:blank` to indicate that the `:` is the protocol suffix and not the
start of a `:blank` named group pattern.

## Properties

**`URLPattern.protocol`**

Returns the URL protocol pattern passed to the constructor.  This value may
be differ from the input to the constructor due to normalization.

**`URLPattern.username`**

Returns the URL username pattern set during construction.  This value may
be differ from the input to the constructor due to normalization.

**`URLPattern.password`**

Returns the URL password pattern set during construction.  This value may
be differ from the input to the constructor due to normalization.

**`URLPattern.hostname`**

Returns the URL username pattern set during construction.  This value may
be differ from the input to the constructor due to normalization.

**`URLPattern.port`**

Returns the URL username pattern set during construction.  This value may
be differ from the input to the constructor due to normalization.

**`URLPattern.pathname`**

Returns the URL username pattern set during construction.  This value may
be differ from the input to the constructor due to normalization.

**`URLPattern.search`**

Returns the URL username pattern set during construction.  This value may
be differ from the input to the constructor due to normalization.

**`URLPattern.hash`**

Returns the URL username pattern set during construction.  This value may
be differ from the input to the constructor due to normalization.

## Events

None

## Methods

**`URLPattern.test()`**

Returns a boolean indicating whether the passed string matches the current pattern.

**`URLPattern.exec()`**

Returns a `URLPatternResult`  object containing detailed information about the match along with capture groups, or null if there is no match.

## Examples

### Filter on a Specific URL Component

The following example shows how a URLPattern filters a
specific URL component.  When the `URLPattern()` constructor is called with a
structured object of component patterns any missing components default to
the `*` wildcard value.

```js
// Construct a URLPattern that matches a specific domain and its subdomains.
// All other URL components default to the wildcard `*` pattern.
const pattern = new URLPattern({
  hostname: `{*.}?example.com`
});

// Prints `{*.}?example.com`
console.log(pattern.hostname);

// All print `*`
console.log(pattern.protocol);
console.log(pattern.username);
console.log(pattern.password);
console.log(pattern.pathname);
console.log(pattern.search);
console.log(pattern.hash);

// Prints `true`
console.log(pattern.test("https://example.com/foo/bar"));

// Prints `true`
console.log(pattern.test({ hostname: "cdn.example.com" }));

// Prints `true`
console.log(pattern.test("custom-protocol://example.com/other/path?q=1"));

// Prints `false` because the hostname component does not match
console.log(pattern.test("https://cdn-example.com/foo/bar"));
```

### Construct a URLPattern from a Full URL String.

The following example shows how a URLPattern can be constructed from a full
URL string with patterns embedded.  For example, a `:` can be both the URL
protocol suffix, like `https:`, and the beginning of a named pattern group,
like `:foo`.  If there is no ambiguity between whether a character is a part
of the URL syntax or part of the pattern syntax then it just works.

```js
// Construct a URLPattern that matches URLs to CDN servers loading jpg images.
// URL components not explicitly specified, like search and hash here, result
// in the empty string similar to the URL() constructor.
const pattern = new URLPattern("https://cdn-*.example.com/*.jpg");

// Prints `https`
console.log(pattern.protocol);

// Prints `cdn-*.example.com`
console.log(pattern.hostname);

// Prints `/*.jpg`
console.log(pattern.pathname);

// All print `""`
console.log(pattern.username);
console.log(pattern.password);
console.log(pattern.search);
console.log(pattern.hash);

// Prints `true`
console.log(
    pattern.test("https://cdn-1234.example.com/product/assets/hero.jpg");

// Prints `false` because the search component does not match
console.log(
    pattern.test("https://cdn-1234.example.com/product/assets/hero.jpg?q=1");
```

### Constructing a URLPattern with an Ambiguous URL String.

The following example shows how a URLPattern constructed from an ambiguous
string will favor treating characters as part of the pattern syntax.  In
this case the `:` character could be the protocol component suffix or it
could be the prefix for a pattern named group.  The constructor chooses
to treat this as part of the pattern and therefore determines this is
a relative pathname pattern.  Since there is no base URL the relative
pathname cannot be resolved and it throws an error.

```js
// Throws because this is interpreted as a single relative pathname pattern
// with a ":foo" named group and there is no base URL.
const pattern = new URLPattern("data:foo*");
```

### Escaping Characters to Disambiguate URLPattern Constructor Strings

The following example shows how an ambiguous constructor string character
can be escaped to be treated as a URL separator instead of a pattern
character.  Here `:` is escaped as `\\:`.

```js
// Constructs a URLPattern treating the `:` as the protocol suffix.
const pattern = new URLPattern("data\\:foo*");

// Prints `data`
console.log(pattern.protocol);

// Prints `foo*`
console.log(pattern.pathname);

// All print `""`
console.log(pattern.username);
console.log(pattern.password);
console.log(pattern.hostname);
console.log(pattern.port);
console.log(pattern.search);
console.log(pattern.hash);

// Prints `true`
console.log(pattern.test("data:foobar"));
```

### Using Base URLs for test() and exec()

The following example shows how input values to `test()` and `exec()` can use
base URLs.

```js
const pattern = new URLPattern({ hostname: "example.com", pathname: "/foo/*" });

// Prints `true` as the hostname based in the dictionary `baseURL` property
// matches.
console.log(
    pattern.test({ pathname: "/foo/bar", baseURL: "https://example.com/baz" }));

// Prints `true` as the hostname in the second argument base URL matches.
console.log(pattern.test("/foo/bar", "https://example.com/baz"));

// Throws because the second argument cannot be passed with a dictionary input.
try {
  pattern.test({ pathname: "/foo/bar" }, "https://example.com/baz");
} catch (e) {}

// The `exec()` method takes the same arguments as `test()`.
const result = pattern.exec("/foo/bar", "https://example.com/baz");

// Prints `/foo/bar`
console.log(result.pathname.input);

// Prints `bar`
console.log(result.pathname.groups[0]);

// Prints `example.com`
console.log(result.hostname.input);
```

### Using base URLs in the URLPattern Constructor.

The follow example shows how base URLs can also be used to construct the
URLPattern.  It's important to note that the base URL in these cases is
treated strictly as a URL and cannot contain any pattern syntax itself.

Also, since the base URL provides a value for every component the resulting
URLPattern will also have a value for every component; even if it's the
empty string.  This means you do not get the "default to wildcard" behavior.

```js
const pattern1 = new URLPattern({ pathname: "/foo/*",
                                  baseURL: "https://example.com" });

// Prints `https`
console.log(pattern1.protocol);

// Prints `example.com`
console.log(pattern1.hostname);

// Prints `/foo/*`
console.log(pattern1.pathname);

// All print `""`
console.log(pattern1.username);
console.log(pattern1.password);
console.log(pattern1.port);
console.log(pattern1.search);
console.log(pattern1.hash);

// Equivalent to pattern1
const pattern2 = new URLPattern("/foo/*", "https://example.com" });

// Throws because a relative constructor string must have a base URL to resolve
// against.
try {
  const pattern3 = new URLPattern("/foo/*");
} catch (e) {}
```

### Accessing Matched Group Values

The following example shows how input values that match pattern groups can later
be accessed from the `exec()` result object.  Unnamed groups are assigned index
numbers sequentially.

```js
const pattern = new URLPattern({ hostname: "*.example.com" });
const result = pattern.exec({ hostname: "cdn.example.com" });

// Prints `cdn`
console.log(result.hostname.groups[0]);

// Prints `cdn.example.com`
console.log(result.hostname.input);

// Prints `[{ hostname: "cdn.example.com" }]`
console.log(result.inputs);
```

### Accessing Matched Group Values Using Custom Names

The following example shows how groups can be given custom names which can
be used to accessed the matched value in the result object.

```js
// Construct a URLPattern using matching groups with custom names.  These
// names can then be later used to access the matched values in the result
// object.
const pattern = new URLPattern({ pathname: "/:product/:user/:action" });
const result = pattern.exec({ pathname: "/store/wanderview/view" });

// Prints `store`
console.log(result.pathname.groups.product);

// Prints `wanderview`
console.log(result.pathname.groups.user);

// Prints `view`
console.log(result.pathname.groups.action);

// Prints `/store/wanderview/view`
console.log(result.pathname.input);

// Prints `[{ pathname: "/store/wanderview/view" }]`
console.log(result.inputs);
```

### Custom Regular Expression Groups

The following example shows how a matching group can use a custom regular
expression.

```js
const pattern = new URLPattern({ pathname: "/(foo|bar)" });

// Prints `true`
console.log(pattern.test({ pathname: "/foo" }));

// Prints `true`
console.log(pattern.test({ pathname: "/bar" }));

// Prints `false`
console.log(pattern.test({ pathname: "/baz" }));

const result = pattern.exec({ pathname: "/foo" });

// Prints `foo`
console.log(result.pathname.groups[0]);
```

### Named Group with a Custom Regular Expression

The following example shows how a custom regular expression can be used with a
named group.

```js
const pattern = new URLPattern({ pathname: "/:type(foo|bar)" });
const result = pattern.exec({ pathname: "/foo" });

// Prints `foo`
console.log(result.pathname.groups.type);
```

### Making Matching Groups Optional

The following example shows how a matching group can be made optional by placing
a `?` modifier after it.  For the pathname component this also causes any
preceding `/` character to also be treated as an optional prefix to the group.

```js
const pattern = new URLPattern({ pathname: "/product/(index.html)?" });

// Prints `true`
console.log(pattern.test({ pathname: "/product/index.html" }));

// Prints `true`
console.log(pattern.test({ pathname: "/product" }));

const pattern2 = new URLPattern({ pathname: "/product/:action?" });

// Prints `true`
console.log(pattern2.test({ pathname: "/product/view" }));

// Prints `true`
console.log(pattern2.test({ pathname: "/product" }));

// Wildcards can be made optional as well.  This may not seem to make sense
// since they already match the empty string, but it also makes the prefix
// `/` optional in a pathname pattern.
const pattern3 = new URLPattern({ pathname: "/product/*?" });

// Prints `true`
console.log(pattern3.test({ pathname: "/product/wanderview/view" }));

// Prints `true`
console.log(pattern3.test({ pathname: "/product" }));

// Prints `true`
console.log(pattern3.test({ pathname: "/product/" }));
```

### Making Matching Groups Repeated

The following example shows how a matching group can be made repeated by placing
a `+` modifier after it.  In the pathname component this also treats the
`/` prefix as special.  It is repeated with the group.

```js
const pattern = new URLPattern({ pathname: "/product/:action+" });
const result = pattern.exec({ pathname: "/product/do/some/thing/cool" });

// `do/some/thing/cool`
result.pathname.groups.action;

// Prints `false`
console.log(pattern.test({ pathname: "/product" }));
```

### Making Matching Groups Optional and Repeated

The following example shows how a matching group can be made both optional and
repeated.  This is done by placing a `*` modifier after the group.  Again, the
pathname component treats the `/` prefix as special.  It both becomes optional
and is also repeated with the group.

```js
const pattern = new URLPattern({ pathname: "/product/:action*" });
const result = pattern.exec({ pathname: "/product/do/some/thing/cool" });

// Prints `do/some/thing/cool`
console.log(result.pathname.groups.action);

// Prints `true`
console.log(pattern.test({ pathname: "/product" }));
```

### Using a Custom Prefix or Suffix for an Optional or Repeated Modifier

The following example shows how curly braces can be used to denote a custom
prefix and/or suffix to be operated on by a subsequent `?`, `*`, or `+`
modifier.

```js
const pattern = new URLPattern({ hostname: "{:subdomain.}*example.com" });

// Prints `true`
console.log(pattern.test({ hostname: "example.com" }));

// Prints `true`
console.log(pattern.test({ hostname: "foo.bar.example.com" }));

// Prints `false`
console.log(pattern.test({ hostname: ".example.com" }));

const result = pattern.exec({ hostname: "foo.bar.example.com" });

// Prints `foo.bar`
console.log(result.hostname.groups.subdomain);
```

### Example: Making text optional or repeated without a matching group.

The following example shows how curly braces can be used to denote text
without a matching group can be made optional or repeated without a
matching group.

```js
const pattern = new URLPattern({ pathname: "/product{/}?" });

// Prints `true`
console.log(pattern.test({ pathname: "/product" }));

// Prints `true`
console.log(pattern.test({ pathname: "/product/" }));

const result = pattern.exec({ pathname: "/product/" });

// Prints `{}`
console.log(result.pathname.groups);
```

### Using Multiple Components and Features at Once

The following example shows how many features can be combined across multiple
URL components.

```js
const pattern = new URLPattern({
  protocol: "http{s}?",
  username: ":user?",
  password: ":pass?",
  hostname: "{:subdomain.}*example.com",
  pathname: "/product/:action*",
});

const result = pattern.exec("http://foo:bar@sub.example.com/product/view?q=12345");

// Prints `foo`
console.log(result.username.groups.user);

// Prints `bar`
console.log(result.password.groups.pass);

// Prints `sub`
console.log(result.hostname.groups.subdomain);

// Prints `view`
console.log(result.pathname.groups.action);
```

[path-to-regexp]: https://github.com/pillarjs/path-to-regexp
