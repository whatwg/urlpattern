# Service Worker Scope Pattern Matching Explainer

[TAG Review](https://github.com/w3ctag/design-reviews/issues/417)

## Introduction

The service worker spec [[0]] uses a mechanism to match pages (as well as other clients, like workers) to a controlling service worker registration.  This mechanism is called the “scope” and it is used to prefix-match against the URL of the page.  Each service worker registration can only have a single scope.

The current service worker scope system works well for many cases, but can be problematic for sites with multiple teams working independently.  One team may be responsible for one sub-path on the site while a different team is responsible for another sub-path.  If these separate parts of the site are completely disjoint, then each team can easily manage their service worker without risk of impacting the other team.

Often, however, one team’s area is nested under a part of the path controlled by a different team.  The canonical example is a team responsible for the top level page and a team working on a product limited to any other path on the site; e.g. `foo.com/` vs `foo.com/product`.  In these cases, the single scope with default prefix-matching makes it difficult for the team working on the encompassing path to use service workers without introducing risk to teams working on products hosted on the nested paths.

In particular, the risk involved with service worker FetchEvent handlers is significant for sites.  Specifically:



1.  The performance profile of the page will be altered when controlled by a service worker.  With current service worker implementations this is true for even empty FetchEvent handlers.
1.  Unexpected request URLs may confuse a service worker script causing functional breakage.
1.  When network requests are broken on a page, it can be difficult for the developer to detect and correct the issue.
1.  If products on a site previously used appcache for offline support, registering a service worker will break that feature.  For example, if the top level product team has migrated to service worker offline support, but a team on a sub-path has not done that work yet and is still using appcache.

Storage APIs are also often shared within an origin and that also comes with risks.  The storage APIs, however, offer exact naming allowing teams to avoid conflicting with one another.  Ideally, developers should have similar naming control to be able to use service workers without forcing these risks on other teams sharing the same origin.

This explainer proposes to enhance the service worker scope mechanism to use a matching algorithm that gives the site more control.  Specifically, we propose to allow the site to specify a pattern-based match for the scope.  For example:


```javascript
// Service worker controls `/foo` and `/foo/*`, but
// does not control `/foobar`.
navigator.serviceWorker.register(scriptURL, {
    scope: new URLPattern({
      baseURL: self.location,
      path: '/foo/?*'
    })
});
```


This kind of control is in line with other products that map URLs to software logic.  Application servers, proxies, and client-side routing systems all offer control over how a URL is matched.  Service workers should offer the same capability.  See the references section for links to various URL routing systems for comparison.

Note, the service worker spec had glob [[1]] matching long ago and it was removed [[2]].  At the time it was believed the exact match behavior was not necessary.  Over time, however, it has become clear that there are sites that are having trouble fully adopting service workers since they cannot control their root origin URL without impacting all their various products hosted on sub-paths.

This explainer will also attempt to expose the pattern matching behavior as a separate primitive that sites can use independently in their script for other purposes; e.g. client-side routing logic, etc.


## Goals



*   This effort will allow teams to better map a controlling service worker to the subset of a site that it owns and maintains.  Specifically, we want to support the known use cases that have been encountered in the real world:
    *   A root URL service worker and products on a subpath.
    *   A product service worker where there is overlap at part of the path; e.g. products `/foo` and `/foobar`.
    *   A product service worker based on a query parameter.
*   This effort will maintain backward compatibility with the existing service worker API.
*   This effort will provide a pattern matching platform primitive that can be used by generic javascript code.
    *   This includes providing a mechanism for the pattern matching to be extended in the future.
    *   This includes using a syntax familiar to developers working on modern web sites.
*   This effort will support fast browser navigations (which depends on the complexity of the service worker scope matching algorithm).


## Non-Goals



*   This effort will not change the handling of subresource requests once a page is already controlled by a service worker.  There are other efforts, such the declarative routing proposal [[3]], that are focused on subresources.
*   This effort will not support discrete lists of scope entries, such as multiple scopes for a single registration.  This could be a useful feature, but is orthogonal to the matching of a single scope entry.  It's excluded here to reduce complexity.


## URLPattern

First, we propose to add a new API to expose URL pattern matching as a web-platform primitive.  This kind of matching is common within URL routing software in general.  There are many different possible approaches we could take for pattern matching, but we propose to start with something relatively simple that can be extended later.  The simple syntax would be adequate to express the restrictions desired by sites known to have problems with current scope matching.

The API would roughly like this:


```javascript
let pattern = new URLPattern({
  baseURL: self.origin,
  path: <pattern string>,
  search: {
    value: <pattern string>,
    params: [{
      key: <pattern string>,
      value: <pattern string>
    }]
});

if (pattern.test(urlString)) {
  // do something
}
```


Pattern strings would support the following features to start:



*   By default static text is exactly matched.
*   The `*` pattern character matches zero or more characters.
*   The `?` pattern character makes the preceding character optional.
*   The `\` character escapes the following pattern character.

In addition, there is a context-specific behavior:



*   In a path pattern, the `/?` sequence would indicate a break between path segments.

The scheme, host, port, username, and password components of the URLPattern are derived from the provided `baseURL`.

The path pattern string may be relative, in which case it is resolved against the base URL.

The search "value" and "params" options are mutually exclusive.  Only one may be present in a given URLPattern.  The "value" option applies the pattern across the entire search string.  The "params" option requires that the given key/value pairs match search parameters present in the URL.

The URLPattern will also define a number of internal concepts that will be used during integration with other browser APIs:



*   The "non-variable prefix" is defined to be the fully resolved, static exact matching components up until the first variable pattern character.  So if there is a path pattern like `baz/?*` with a base URL of `https://foo.com/bar`, then the non-variable prefix would be `https://foo.com/bar/baz`.
*   Each variable pattern matching feature is ordered by "specificity".  A `?` optional character is considered more specific than a `*` wildcard.
*   When a match is made the URLPattern will track how many "variable characters" were matched by pattern characters.  For example, a path pattern `/*` matching `/foo` would have matches 3 variable characters.
*   When a match is made the URLPattern will also track the number of "variable characters before the last static text".  So a pattern like `/*bar*` matching `/foobarbaz` would have 3 variable characters before the last static text.


## Service Worker API

The URLPattern API would then be integrated with service workers like this:


```javascript
let reg1 = await navigator.serviceWorker.register(scriptURL, {
  scope: new URLPattern({
    baseURL: self.origin,
    path: '/foo/?*',
    search: { value: '*' },
  })
});
assert_true(reg1.scope instanceof URLPattern);
assert_true(reg1.scopePattern instanceof URLPattern);

let reg2 = await navigation.serviceWorker.get('/foo');
assert_equals(reg1, reg2);
```


Legacy scope strings would still be supported:


```javascript
// Legacy API usage
let reg2 = await navigator.serviceWorker.register(scriptURL, {
  scope: '/bar/baz'
});
assert_equals('string', typeof reg2.scope);
assert_true(reg2.scopePattern instanceof URLPattern);
```


Essentially the externally facing API treats the scope as a DOMString or a URLPattern.  Internally the browser would convert the legacy string representation to a pattern.  In most cases this would consist of appending a `*` wildcard to the end of the path.  If the service worker scope includes a URL query string component, then the path is left as an exact match and the wildcard is added to the end of the search "value" pattern.

As always you can pass a URL that matches the scope to `navigator.serviceWorker.get()` to get a handle to the registration again.  Internal algorithms would still treat the scope as a key using the pattern object instead of a string.  Patterns would have to be defined exactly the same to be considered the same key.

Service worker scopes will throw if the URLPattern is too complex.  Specifically, a scope URLPattern is restricted to:



*   Trailing "*" wildcard characters.  In-fix wildcards are not supported.
*   At most one "?" optional character which may only operate on a slash; e.g. "/?".
*   At most one search parameter pattern.

These restrictions meet the known use cases with a minimal risk of performance problems.

URLPattern objects used as service worker scopes must have a “non-variable prefix” that completely encompasses the origin.  This is all patterns in the current proposal, but in the future URLPattern may allow variable origins.

When matching a navigation URL against a scope the most specific scope is chosen.  This will mostly be handled via the "non-variable prefix", but there are a number of steps.  See the detailed design section for more details.

By default the service worker script URL is still required to live at or above the scope in the path as defined by the specification.  Instead of comparing against the entire scope, however, the "non-variable prefix" for the scope pattern is used.  This can still be overridden using the `ServiceWorkerAllowed` header.


## Web App Manifest

The manifest spec also defines a scope [[4]].  While this scope definition is separate from the service worker scope, the manifest spec attempts to keep them in sync.

Using a URLPattern in a manifest would look something like this:


```json
{
  "name": "FooApp",
  "scope": "https://foo.com/app/",
  "scopePattern": {
    "baseURL": "https://foo.com/",
    "path": "/app/?*"
  }
}
```


The pattern is specified in a new `scopePattern` json value.  Both the legacy `scope` value and the new `scopePattern` can be specified.  In that case, the `scopePattern` takes precedence.  This is done so the same manifest can be used with older browsers that don't support `scopePattern` yet and therefore fall back to `scope`.

Note, some platforms, like Android, have limitations on how apps can register to handle incoming URLs.  Apps with complex scope patterns may not be able to handle navigation URLs automatically as result.  With the current syntax proposal and scope pattern restrictions "too complex" mainly means a pattern that depends on the search value.


## Key Scenarios


### Root URL Service Worker

The common case that comes up repeatedly is one team managing the root of the site and a separate team managing a product on a sub-path.  Service workers should support a service worker at the root without impacting the team on the sub-path.


```javascript
// Service worker controlling '/' exactly.
navigator.serviceWorker.register('/root-sw.js', {
  scope: new URLPattern({
    baseURL: self.location,
    path: '/'
  })
});

// Product hosted at '/sub/path/product' is not controlled.
```



### Products With Overlapping Path Segment Names

Similar to the previous scenario, it's also possible for products to be hosted on sub-paths that overlap at just one segment of the path.  A real example highlighted in issue 1272 [[5]]:



*   `https://google.com/maps` which also includes pages under the `maps/` sub-path.
*   `https://google.com/mapsearch` which includes pages under the `mapsearch/` sub-path

To register a service worker for just the `/maps` product you would use the `/?` optional slash that also implies a path segment break:


```javascript
// Service worker controlling /maps and everything under /maps/.
// Does not control /mapsearch.
navigator.serviceWorker.register('/maps/maps-sw.js', {
  scope: new URLPattern({
    baseURL: self.location,
    path: '/maps/?*`
  })
});
```



### Search Parameters

We have at least one report of a product that is routed to via a search parameter.  This is supported via the search params feature:


```javascript
navigator.serviceWorker.register('/param-sw.js', {
  scope: new URLPattern({
    baseURL: self.location,
    path: '/',
    search: {
      params: [{
        key: 'product',
        value: 'foo'
      }]
    }
  });
});
```


This causes the service worker to control `/?product=foo` and `/?other=bar&product=foo`, but not `/`.


## Detailed Design Decision


### Page Loading Performance

Service worker scope matching is particularly performance sensitive.  Every navigation the browser makes must quickly determine whether it matches a scope or not.  This means the algorithm affects sites that don’t use service workers at all.

The “non-variable prefix” requirement enables us to quickly exclude unrelated origins.  In addition, since it effectively matches our current prefix-matching behavior it means sites that don’t actually use new wildcard characters should observe no performance impact their URLs.

There is still a concern, however, about denial-of-service attacks where it takes so long to match one origin that it delays the match on the next origin.  For example, if evil.com constructs a pathological scope pattern and tricks a user to visit their site they could block other tabs from loading.

To mitigate this issue we propose to restrict scope patterns to a simpler syntax than generally available to URLPattern.  These restrictions are noted in the service worker API section above, but repeated here.

Scope patterns are restricted to:



*   Trailing `*` wildcard characters.  In-fix wildcards are not supported.
*   At most one `?` optional character which may only operate on a slash; e.g. `/?`.
*   At most one search parameter pattern.

These restrictions limit the amount of possible back-tracking during a pattern match.  In addition, they avoid creating pathological sets of search parameters.

Another possible attack is to register many service workers scopes with the same "non-variable prefix", but different variable components.  Due to pattern restrictions this is only really possible by using the search params feature.

The implementation should be able to mitigate this attack by yielding to other work if there is a large list of scopes to analyze and a time threshold is exceeded.  If that is not possible for some reason, we could add a restriction on the number of scopes with the same "non-variable prefix" and start throwing from `register()` when it's exceeded.


### ServiceWorkerAllowed Behavior

By default the service worker spec requires that the worker script is hosted at a path equal to or higher than the scope.  For example, if the scope is ‘/’, then you could not host the service worker script at ‘/scripts/sw.js’.  This behavior can be overridden to an arbitrary path using the ServiceWorkerAllowed header.

This mechanism will be maintained by using the existing algorithm and the URLPattern’s “non-variable prefix”.  This will in effect match the existing behavior and should be functionally adequate for sites using the new pattern behavior.


### Scope Match Ordering

The service worker spec requires that scope strings be ordered such that the most specific is matched first.  We must define a similar ordering using patterns internally.

We propose the following steps:



1.  Prefer the scope with the longest "non-variable prefix".
1.  If the "non-variable prefix" is equal, then prefer the scope whose first pattern character is most specific.
1.  If both the "non-variable prefix" and the first pattern character are equal, then prefer the scope that matches with the least number of "variable characters".
1.  If there is still a tie, then prefer the scope that has the fewest "variable characters before the last static text".

Step (4) is intended to handle ambiguous cases involving search parameters.  Consider these two patterns:



*   new URLPattern({ search: { param: { key: 'foo', value: '1' }}})
*   new URLPattern({ search: { param: { key: 'bar', value: '2' }}})

Both of these scopes will match the URL `/?foo=1&bar=2`.  In addition, they will both also have the same "non-variable prefix" of `/?`, the same first pattern character, and the same number of variable characters matched.  Step (4), however, will pick the "foo=1" scope since "foo" comes first in the URL.


### URL Query Strings

URL query strings require special attention.  Their behavior in service worker scopes is a bit odd.  Consider these two scopes:


```javascript
let scope1 = '/foo';
let scope2 = '/foo?';
```


The first scope will match against both paths starting with `/foo` and all query strings.  The second scope will match against paths that are exactly `/foo`.  In addition, query strings are optional for the first scope but required for the second scope.

This behavior is a bit odd and possibly not something we want to extend to URLPattern.  Therefore it's likely we will want to separate the query string matching pattern out into a different option.  For example, this could be the equivalent URLPattern syntax:


```javascript
let scope1 = new URLPattern('/foo*', {
  search: {
    value: '*'
  }
});

let scope2 = new URLPattern('/foo', {
  search: {
    value: '\?*'
  }
});
```


The default query string pattern would likely be `*` to optionally match any query string.  That seems to be the default semantic for most URL routing systems.

While this would match current service worker scope behavior, it's not clear how useful the feature is in general.  The current behavior requires exact ordering of the query parameters specified with a simple prefix match beyond.  In reality, though, query parameters can come in any order and still be valid.  Any slight re-ordering of the query parameters would break the match.

To improve on this situation a more ergonomic API is also provided to match specific search parameters.  The "params" option, however, is mutually exclusive with the general pattern match against the entire search string.  Ideally we would remove the total search string matching feature, but it's necessary for backward compatibility with service worker scopes.


### URLPattern Extensibility

The URLPattern is exposed so that it can be used by sites in their client logic.  The currently proposed syntax, however, is not particularly useful for sites.  Libraries like regexparam [[6]] offer more expressive syntax options.  These are not considered here since they are not needed to support the service worker scope use cases, but we want to allow them to be added in the future.

The main design choice that enables extensibility is the use of the options dictionary parameter passed to the URLPattern constructor.  It permits new fields to be added in the future with little compatibility risk.  In addition, we have tried to design the initial syntax to be consistent popular libraries so common syntax can be integrated with it in an ergonomic way.

Possible future additions include:



*   A path parameter syntax similar to Ruby on Rails's `/:param/index.html` syntax. [[7]]  This would also involve adding a `URLPattern.match()` method that would return a dictionary of matched parameter values.  This would include applying the optional character to the parameter.
*   Groupings such as `/*.(png|jpg)` to match either png or jpg files.  This would include applying the optional character to the groups.
*   Pattern strings for components of the origin.  For example, specifying a wildcard pattern for the host.

Note, some pattern extensions may be incompatible with service worker scopes and would cause registration to fail if used there.  For example, service worker scopes must never have a variable origin.


## Considered Alternatives


### ServiceWorker-Only API Change without URLPattern

Another possibility would be to introduce pattern matching via a service worker specific API change.  Scope matching would be improved, but we would not have to worry about adding the URLPattern API.

This would reduce the risk of this effort, but at the cost of creating an API-specific parser that cannot be reused in the platform.  Given there are already many client-side libraries for URL matching in active use, it seems like exposing URLPattern would be useful to the web ecosystem.  For use cases where URLPattern is adequate the script footprint could be reduced by avoiding the need to load these libraries.


### Regular Expressions

An alternative to introducing URLPattern would be to instead use regular expressions and the existing Regexp object.  This has a number of downsides:



*   The ergonomics of specifying URLs in regular expressions is quite poor due to the excessive amount of character escaping that is needed.
*   Regular expressions can be very complex, making it harder to reason about match performance.
*   Regular expression complexity would also make it difficult to implement service worker scope ordering and ServiceWorkerAllowed behavior.

For these reasons this explainer proposes the pattern approach instead.


### Require Teams to Use Separate Origins

One approach that has been recommended many times in the past (including by me) is that teams should not host different products on the same origin.  Instead each product should have its own isolated origin.  This would avoid the overlapping scope issues and also provide isolation throughout the web platform in storage, communication, etc.

In practice, however, there are often reasons products want to be hosted on the same origin:



*   The site wants a unified experience such that the user does not distinguish between different teams and products that encompass that experience.
*   The different products have shared state in the form of a user profile, configuration, or other data such that its preferable for storage to be shared.
*   Maintaining separate origins increases costs for the site operators.

Another aspect of this idea is that if sites are sharing storage, then they should also be able to share the service worker scope space safely.  The scope prefix-matching, however, makes safely sharing much harder than sharing storage.  Storage entities like caches or databases are uniquely named without any kind of prefix-matching.  This supports safe sharing strategies because the risk of accessing the wrong storage entity is quite small.

Therefore the goal of this explainer is to make it safer to use service workers when multiple teams are sharing an origin.

## Include / Exclude Lists

One feature that is often suggested is to add separate lists of URLs to include or exclude in the scope matching algorithm.  This explainer purposely does not discuss this since it seems a subset of the multiple scopes case.  As mentioned in the non-goals section multiple scopes are orthogonal to how a single scope matches.  Nothing in this explainer should block adding multiple scopes in the future.

Also, its worth noting that exclude lists are also somewhat possible today.  If you have a list of scope sub-paths you want to exclude you can explicitly register empty service workers on each one.  This is somewhat heavyweight since navigating to these sub-paths will still trigger an update check, but they will not incur the risks of applying a FetchEvent handler.  And of course, unless we address the issues discussed in this explainer these exclusion registrations will have eager prefix matching which may not be what the site wants.

## Privacy & Security Considerations

This proposal should not have any negative privacy or security impact.

From a same-origin policy perspective, service worker scopes are already required to be same-origin and that will not change if there are variable pattern characters in the path.

However, there is always increased risk of zero-day security issues when adding new code and particularly adding new parser.  In this case the scope pattern matching must typically be performed in the browser's trusted process.  This makes it a particular threat.

To mitigate the risk of zero-day security issues in scope pattern matching this proposal:



1.  Restricts the complexity of the service worker scope to exact matches, trailing wildcards, a single optional slash, and a single search parameter.  More complex matching syntax will not be supported for service worker scopes.
1.  Supports parsing pattern strings in an untrusted process where they can then be converted to a structured internal representation.  These structured patterns can then be validated and sent to the trusted process for scope matching.  The trusted process can be protected from operating on potentially invalid patterns.

URLPatterns outside of service worker scopes will be exposed to greater parser risk due to supporting more complex patterns.  They will operate, however, completely in untrusted sandboxed processes.

From a privacy perspective this API does not expose any new bits of user information entropy.  it also does not create new opportunities to store data that could be used as a cookie.


## Stakeholder Feedback / Opposition

There is some existing spec discussion in issue 1272 [[5]].

Multiple product teams at Google have requested better control over service worker scope matching.  In particular, the ability to restrict a service worker to a root URL has come up repeatedly.  There are also some products that would like to restrict the service worker to a particular URL query parameter.

We also have feedback from two large e-commerce sites based in the US.

The first e-commerce site provided positive feedback stating the proposal "it is aligned to solve some of the problems that we are facing i.e., different teams maintaining and deploying various parts of a web app."

The second e-commerce site indicated they view their entire site as a single product and would most likely not use the features proposed in this explainer.  They would like a single service worker instance.  They indicated multiples scopes and exclude lists would possibly be useful, though, to restrict the service worker to disjoint sections of their product URL space.

## References & Acknowledgements

Other routing systems for flexibility comparison:

*   https://github.com/lukeed/regexparam
*   https://github.com/pillarjs/path-to-regexp/
*   https://edgeguides.rubyonrails.org/routing.html
*   https://stackoverflow.com/questions/14018215/what-is-the-significance-of-url-pattern-in-web-xml-and-how-to-configure-servlet (links to servlet spec pdf)
*   https://expressjs.com/en/guide/routing.html
*   http://nginx.org/en/docs/http/ngx_http_core_module.html?&_ga=2.193337709.1730038529.1565988792-1175143511.1565988792#location
*   https://reacttraining.com/react-router/web/api/Route

Contributions and review provided by:

*   Matt Falkenhagen
*   Darwin Huang
*   Marijn Kruisselbrink
*   Jeffrey Posnick
*   Victor Costan
*   Dominick Ng
*   R. Samuel Klatchko
*   Kingsley Ngan
*   Matt Giuca
*   Jimmy Shen
*   Kinuko Yasuda
*   Cyrus Kasaaian
*   Kenji Baheux
*   Ralph Chelala
*   Rajesh Jagannathan

References

*   \[0]: https://w3c.github.io/ServiceWorker/
*   \[1]: https://en.wikipedia.org/wiki/Glob_(programming)
*   \[2]: https://github.com/w3c/ServiceWorker/issues/287
*   \[3]: https://github.com/w3c/ServiceWorker/issues/1373
*   \[4]: https://w3c.github.io/manifest/#scope-member
*   \[5]: https://github.com/w3c/ServiceWorker/issues/1272
*   \[6]: https://github.com/lukeed/regexparam
*   \[7]: https://edgeguides.rubyonrails.org/routing.html

[0]: https://w3c.github.io/ServiceWorker/
[1]: https://en.wikipedia.org/wiki/Glob_(programming)
[2]: https://github.com/w3c/ServiceWorker/issues/287
[3]: https://github.com/w3c/ServiceWorker/issues/1373
[4]: https://w3c.github.io/manifest/#scope-member
[5]: https://github.com/w3c/ServiceWorker/issues/1272
[6]: https://github.com/lukeed/regexparam
[7]: https://edgeguides.rubyonrails.org/routing.html
