# Service Worker Scope Pattern Matching Explainer

Table of Contents:

* [Introduction](#introduction)
* [Goals](#goals)
* [Non-Goals](#non-goals)
* [Web APIs](#web-apis)
  * [URLPattern](#urlpattern)
  * [Service Worker API](#service-worker-api)
  * [Web App Manifest](#web-app-manifest)
* [Key Scenarios](#key-scenarios)
  * [Root URL Service Worker](#root-url-service-worker)
  * [Product With Overlapping Path Segment Names](product-with-overlapping-path-segment-names)
  * [JavaScript URL Routing](#javascript-url-routing)
* [Detailed Design Decision](#detailed-design-decision)
  * [Page Loading Performance](#page-loading-performance)
  * [ServiceWorkerAllowed Behavior](#serviceworkerallowed-behavior)
  * [Scope Match Ordering](#scope-match-ordering)
* [Considered Alternatives](#considered-alternatives)
  * [ServiceWorker-Only API Change without URLPattern](#serviceworker-only-api-change-without-urlpattern)
  * [Alternate Pattern Syntax](#alternate-pattern-syntax)
  * [Regular Expressions](#regular-expressions)
  * [Require Teams to Use Separate Origins](#require-teams-to-use-separate-origins)
* [Privacy & Security Considerations](#privacy--security-considerations)
* [Stakeholder Feedback](#stakeholder-feedback)
* [References & Acknowledgements](#references--acknowledgements)

## Introduction

The service worker [spec](https://w3c.github.io/ServiceWorker/) uses a mechanism to match pages (as well as other clients, like workers) to a controlling service worker registration. This mechanism is called the “scope” and it is used to prefix-match against the URL of the page. Each service worker registration can only have a single scope.

The current service worker scope system works well for many cases, but can be problematic for sites with multiple teams working independently. One team may be responsible for one sub-path on the site while a different team is responsible for another sub-path. If these separate parts of the site are completely disjoint, then each team can easily manage their service worker without risk of impacting the other team.

Often, however, one team’s area is nested under a part of the path controlled by a different team. The canonical example is a team responsible for the top level page and a team working on a product limited to any other path on the site; e.g. `foo.com/` vs `foo.com/product`. In these cases, the single scope with default prefix-matching makes it difficult for the team working on the encompassing path to use service workers without introducing risk to teams working on products hosted on the nested paths.

In particular, the risk involved with service worker FetchEvent handlers is significant for sites. Specifically:


1.  The performance profile of the page will be altered when controlled by a service worker. With current service worker implementations this is true for even empty FetchEvent handlers.
1.  Unexpected request URLs may confuse a service worker script causing functional breakage.
1.  When network requests are broken on a page, it can be difficult for the developer to understand what is happening on the client in order to take corrective action.
1.  If products on a site previously used appcache for offline support, registering a service worker will break that feature. For example, if the top level product team has migrated to service worker offline support, but a team on a sub-path has not done that work yet and is still using appcache.

Storage APIs are also often shared within an origin and that also comes with risks. The storage APIs, however, offer exact naming allowing teams to avoid conflicting with one another. Ideally, developers should have similar naming control to be able to use service workers without forcing these risks on other teams sharing the same origin.

This explainer proposes to enhance the service worker scope mechanism to use a matching algorithm that gives the site more control. Specifically, we propose to allow the site to specify a pattern-based match for the scope.  For example:

```javascript
// Service worker controls '/foo' exactly, but not '/foo/bar'.
navigator.serviceWorker.register(scriptURL, {
  scope: new URLPattern({
    baseURL: self.location,
    pathname: '/foo'
  })
});
```

A more complex pattern example:

```javascript
// Service worker controls `/foo` and `/foo/*`, but
// does not control `/foobar`.
navigator.serviceWorker.register(scriptURL, {
  scope: new URLPattern({
    baseURL: self.location,
    pathname: '/foo/*?'
  })
});
```

This kind of control is in line with other products that map URLs to software logic. Application servers, proxies, and client-side routing systems all offer control over how a URL is matched. Service workers should offer the same capability. See the references section for links to various URL routing systems for comparison.

Finally, web developers also often need to match URLs in content level JavaScript as well; e.g. when building client-side routing logic in a single page app (SPA).  This logic is often implemented via javascript that translates pattern syntax into regular expressions.  This logic is often incorporated directly into frameworks or into 3rd party libraries.

This explainer will attempt to satisfy these web developer use cases by exposing a native web API for matching URLs.  In addition, we will attempt to align this primitive with pattern matching mechanisms already popular in javascript libraries.

For example, a web developer would be able to use the same URLpattern primitive in routing code:

```javascript
const pattern = new URLPattern({ pathname: '/api/:product' });
if (let result = pattern.exec(url)) {
  routeTo(result.pathname.groups['product']);
}
```

The goal is to help create a holistic ecosystem where developers can use the same pattern syntax both in javascript and with native browser APIs.


## Goals

*   Allow teams to better map a controlling service worker to the subset of a site that it owns and maintains.  Specifically, we want to support the known use cases that have been encountered in the real world:
    *   A root URL service worker and products on a subpath.
    *   A product service worker where there is overlap at part of the path; e.g. products `/foo` and `/foobar`.
*   Maintain backward compatibility with the existing service worker API.
*   Provide a pattern matching platform primitive that can be used by generic javascript code.
    *   This includes using a syntax familiar to developers working on modern web sites.
*  Support fast browser navigations (which depends on the complexity of the service worker scope matching algorithm).


## Non-Goals

*   This effort will not change the handling of subresource requests once a page is already controlled by a service worker.  There are other efforts, such as the [declarative routing proposal](https://github.com/w3c/ServiceWorker/issues/1373), that are focused on subresources.
*   This effort will not cover matching service worker scopes against specific URL search query parameters.  This appears to be a rare use case.  Also, since query parameters can be reordered in URLs it will likely require a different kind of matching compared to what is needed for the rest of the URL.

## Web APIs

### URLPattern

First, we propose to add a new API to expose URL pattern matching as a web-platform primitive.  Since there are popular libraries already used for matching we also propose to adopt the syntax from one as a popular cowpath.  Specifically, we propose to adopt the syntax from [path-to-regexp](https://github.com/pillarjs/path-to-regexp).  It has 20 million weekly downloads on [npm](https://www.npmjs.com/package/path-to-regexp) and is used in popular projects like [expressjs](https://expressjs.com/) and [react-router](https://github.com/ReactTraining/react-router).

The API would roughly look like this:

```javascript
let pattern = new URLPattern({
  baseURL: self.origin,
  pathname: "/product/*?",
});

if (pattern.test(urlString)) {
  // do something
}
```

Pattern strings will conform to the syntax and many of the features provided by path-to-regexp.  In particular:

* "*" wildcards (in path-to-regexp version 1.7.0)
* named matching groups
* regular expression groups
* group modifiers such as "?", "+", and "*"

In general we will attempt to maintain compatibility with path-to-regexp, but might not support niche features like custom prefixes and suffixes.

We will also expose a "list of patterns" primitive:

```javascript
let pattern = new URLPatternList([
  {
    baseURL: self.origin,
    pathname: "/product",
  },
  {
    baseURL: self.origin,
    pathname: "/product/*"
  }
]);

if (pattern.test(urlString)) {
  // do something
}
```

### Service Worker API

The URLPattern API would then be integrated with service workers like this:

```javascript
let reg1 = await navigator.serviceWorker.register(scriptURL, {
  scope: new URLPattern({
    baseURL: self.origin,
    pathname: '/foo/*?',
  })
});
assert_true(reg1.scope instanceof URLPattern);
assert_true(reg1.scopePattern instanceof URLPattern);

// Check which service worker controls '/foo':
let reg2 = await navigation.serviceWorker.getRegistration('/foo');
assert_equals(reg1, reg2);
```

Legacy scope strings would still be supported:

```javascript
// Legacy API usage
let reg2 = await navigator.serviceWorker.register(scriptURL, {
  scope: '/bar/baz'
});
assert_equals(typeof reg2.scope, 'string');
assert_true(reg2.scopePattern instanceof URLPattern);
```

Essentially the externally facing API treats the scope as a string, URLPattern, or URLPatternList. Internally the browser would convert the legacy string representation to a pattern.

As always you can pass a URL that matches the scope to navigator.serviceWorker.getRegistration() to get a handle to the registration again. Internal algorithms would still treat the scope as a key using the pattern object instead of a string.

Service worker register() will reject if a scope URLPattern uses certain features. Specifically, a scope URLPattern is restricted to:

* Variable components like wildcards are only allowed in pathname and search components.
* No regular expressions besides `(.*)` which matches the `*` wildcard.
* Variable components like wildcards can only be in trailing position.

These restrictions meet the known use cases with a minimal risk of [performance problems](#page-loading-performance).

Service worker registrations will also be able to use URLPatternList as a scope.  This effectively provides an allow list of scope patterns to match against.  If a registration has one or more entries in its scope list that matches a scope pattern from a different registration then an error will be thrown.  If the complete scope lists are identical, however, then it's treated as updating the existing registration.

Finally, there will be some limits on the number of patterns that can nest one another in a way that forces linear scanning in order to complete a match.  This should be rare in normal use cases, but necessary to prevent abuse.

## Web App Manifest

The manifest spec also defines a [scope](https://w3c.github.io/manifest/#scope-member).  While this scope definition is separate from the service worker scope, the manifest spec attempts to keep them in sync.

Using a URLPattern in a manifest would look something like this:


```javascript
{
  "name": "FooApp",
  "scope": "https://foo.com/app/",
  "scopePattern": {
    "baseURL": "https://foo.com/",
    "pathname": "/app/*?"
  }
}
```

The pattern is specified in a new `scopePattern` json value.  Both the legacy `scope` value and the new `scopePattern` can be specified.  In that case, the `scopePattern` takes precedence.  This is done so the same manifest can be used with older browsers that don't support `scopePattern` yet and therefore fall back to `scope`.

## Key Scenarios

### Root URL Service Worker

The common case that comes up repeatedly is one team managing the root of the site and a separate team managing a product on a sub-path.  Service workers should support a service worker at the root without impacting the team on the sub-path.

```javascript
// Service worker controlling '/' exactly.
navigator.serviceWorker.register('/root-sw.js', {
  scope: new URLPattern({
    baseURL: self.location,
    pathname: '/'
  })
});

// '/' is controlled, but product hosted at '/sub/path/product' is not controlled.
```

### Products With Overlapping Path Segment Names

Similar to the previous scenario, it's also possible for products to be hosted on sub-paths that overlap at just one segment of the path.  A real example highlighted in [issue 1272](https://github.com/w3c/ServiceWorker/issues/1272):

*   `https://google.com/maps` which also includes pages under the `maps/` sub-path.
*   `https://google.com/mapsearch` which includes pages under the `mapsearch/` sub-path

To register a service worker for just the /maps product you would use an optional modifier like "?":

```javascript
// Service worker controlling /maps and everything under /maps/.
// Does not control /mapsearch.
navigator.serviceWorker.register('/maps/maps-sw.js', {
  scope: new URLPattern({
    baseURL: self.location,
    pathname: '/maps/*?`
  })
});
```

Per the path-to-regexp behavior the optional modifier makes the preceding prefix separator, "/", also optional.  This use case can also be met by using a URLPatternList with an exact match entry and a wildcard entry.

### JavaScript URL Routing

A common use case for URL matching in JavaScript is to "route" a URL to the appropriate backing business logic.  For example, service worker FetchEvent handlers often need to take different action based on the URL of the request.  Adopting the syntax from path-to-regexp should satisfy these use cases as the library is already widely used by web developers in the wild.

In addition to real examples such as [expressjs](https://expressjs.com/en/guide/routing.html), a contrived bit of routing code might look like:

```javascript
const imagePattern = new URLPattern({
  pathname: '/*.:imagetype(jpg|png|gif)'
});
if (let result = imagePattern.exec(url)) {
  return handleImage(result.pathname.groups['imagetype']);
}

const apiPattern = new URLPattern({
  pathname: '/api/:product/:param?'
});
if (let result = apiPattern.exec(url)) {
  return handleAPI(result.pathname.groups['product'],
                   result.pathname.groups['param']);
}
```

## Detailed Design Decision

### Page Loading Performance

Service worker scope matching is particularly performance sensitive. Every navigation the browser makes must quickly determine whether it matches a scope or not. This means the algorithm affects sites that don’t use service workers at all.

Only supporting variable values like wildcards at the end of the pathname or search components means scopes will always have a non-variable prefix.  This enables us to quickly exclude unrelated origins. In addition, since it effectively matches our current prefix-matching behavior it means sites that don’t actually use new wildcard characters should observe no performance impact on their navigations.

Forbidding the use of general purpose regular expression groups in service worker scope patterns also helps avoid unpredictable performance characteristics.
There is still a concern, however, potentially having to check multiple scopes to determine if there is a match during navigation.  For example, if you have scope patterns:

* /abcd
* /abc
* /ab
* /a
* /*

Then matching the navigation URL "/abcde" will require inspecting 5 patterns.  In abusive cases this could lead to excessive checking.
To mitigate this issue we will reject registrations that would result in too many nested, non-greedy scope patterns.  For example, we could set the limit at 10 nested scopes.  This should be reasonably niche and not impact real use cases while preventing abuse.

### ServiceWorkerAllowed Behavior

By default the service worker spec requires that the worker script is hosted at a path equal to or higher than the scope. For example, if the scope is ‘/’, then you could not host the service worker script at ‘/scripts/sw.js’. This behavior can be overridden to an arbitrary path using the Service-Worker-Allowed header.

This mechanism will be maintained by using the existing algorithm and the URLPattern’s “non-variable prefix”. This will in effect match the existing behavior and should be functionally adequate for sites using the new pattern behavior.  For example, if the pattern is `/foo/*`, then the non-variable prefix will be `/foo/` which will allow scripts to be hosted at `/` or `/foo/` levels.

For registrations that use a URLPatternList, the service worker script location must be valid for every individual URLPattern within that list.  The Service-Worker-Allowed header can of course override this limitation.

### Scope Match Ordering

The service worker spec requires that scope strings be ordered such that the most specific is matched first. We must define a similar ordering using patterns internally.
Generally the ordering will be based on the non-variable prefix of the scope pattern.  Then ordering will be dependent on the specificity of the remaining part of the pattern.  For example, a pattern without a wildcard is more specific than a pattern with a wildcard, etc.  For example, `/foo/` will be considered more specific than `/foo/*` which will in turn be more specific than `/foo/*?`.

## Considered Alternatives

### ServiceWorker-Only API Change without URLPattern

Another possibility would be to introduce pattern matching via a service worker and manifest specific API change. Scope matching would be improved, but we would not have to worry about adding the URLPattern API.

This would reduce the risk of this effort, but at the cost of creating an API-specific parser that cannot be reused in the platform. Given there are already many client-side libraries for URL matching in active use, it seems like exposing URLPattern would be useful to the web ecosystem. For use cases where URLPattern is adequate the script footprint could be reduced by avoiding the need to load these libraries.

### Alternate Pattern Syntax

This effort proposes to use the pattern syntax popularized by the path-to-regexp library.  While this is a popular library used in well known projects, there are undoubtedly other options available.  Many of those other options, however, seem intricately tied to their owning project and not split out into a reusable form.  We have chosen path-to-regexp because it both provides the features necessary for it to be popular with developers and is separated enough from projects to be reasoned about on its own.

Another option would be to create a new syntax from scratch.  This would likely be an expensive process with a high likelihood of producing something that is not a good fit for developers.  There seem to be enough cowpaths in this space that we should pave one instead of attempting to independently determine what developers need.  Therefore we greatly favor using an existing syntax already used by javascript developers.

### Regular Expressions

An alternative to introducing URLPattern would be to instead use regular expressions and the existing RegExp object. This has a number of downsides:

* The ergonomics of specifying URLs in regular expressions is quite poor due to the excessive amount of character escaping that is needed.
* Regular expressions can be very complex, making it harder to reason about match performance.
* Regular expression complexity would also make it difficult to implement service worker scope ordering and Service-Worker-Allowed behavior.

For these reasons this explainer proposes the pattern approach instead.  We do, however, try to match the ergonomics of RegExp by mimicking its methods like `test()` and `exec()`.  It should also be possible to add a `toRegExp()` method that exposes an equivalent regular expression.  This would allow developers to use the URLPattern ergonomics while still easily integrating with existing software that uses regular expressions.

### Require Teams to Use Separate Origins

One approach that has been recommended many times in the past (including by me) is that teams should not host different products on the same origin.  Instead each product should have its own isolated origin.  This would avoid the overlapping scope issues and also provide isolation throughout the web platform in storage, communication, etc.

In practice, however, there are often reasons products want to be hosted on the same origin:

*   The site wants a unified experience such that the user does not distinguish between different teams and products that encompass that experience.
*   The different products have shared state in the form of a user profile, configuration, or other data such that its preferable for storage to be shared.
*   Maintaining separate origins increases costs for the site operators.

Another aspect of this idea is that if sites are sharing storage, then they should also be able to share the service worker scope space safely.  The scope prefix-matching, however, makes safely sharing much harder than sharing storage.  Storage entities like caches or databases are uniquely named without any kind of prefix-matching.  This supports safe sharing strategies because the risk of accessing the wrong storage entity is quite small.

Therefore the goal of this explainer is to make it safer to use service workers when multiple teams are sharing an origin.

## Privacy & Security Considerations

This proposal should not have any negative privacy or security impact.

From a same-origin policy perspective, service worker scopes are already required to be same-origin and that will not change if there are variable pattern characters in the path.

However, there is always an increased risk of zero-day security issues when adding new code and particularly adding new parser. In this case the scope pattern matching must typically be performed in the browser's trusted process. This makes it a particular threat.

To mitigate the risk of zero-day security issues in scope pattern matching this proposal:

1. Restricts the complexity of the service worker scope; e.g. exact matches and trailing wildcards. More complex matching syntax will not be supported for service worker scopes.
1. Using a separate primitive web API supports parsing pattern strings immediately in the js context.  In most browsers this translates to parsing in an untrusted process.  The patterns can then be converted to a structured internal representation. These structured patterns can then be validated and sent to the trusted process for scope matching. The trusted process can be protected from operating on potentially invalid patterns.
1. URLPatterns outside of service worker scopes will be exposed to greater parser risk due to supporting more complex patterns. They will operate, however, completely in untrusted sandboxed processes similar to other existing parsers; e.g. HTML.

Currently service workers have a weak path-based security check to prevent a service worker script in one path location to control pages in a completely disjoint subpath.  The intention is to try to make things slightly more safe for sites that host separate user data on different subpaths.  This proposal maintains the same protections as discussed in the [ServiceWorkerAllowed section](#serviceworkerallowed-behavior).

From a privacy perspective this API does not expose any new bits of user information entropy. it also does not create new opportunities to store data that could be used as a cookie.

## Stakeholder Feedback

There is some existing spec discussion in [issue 1272](https://github.com/w3c/ServiceWorker/issues/1272).

Multiple product teams at Google have requested better control over service worker scope matching. In particular, the ability to restrict a service worker to a root URL has come up repeatedly. There are also some products that would like to restrict the service worker to a particular URL query parameter.

We also have feedback from two large e-commerce sites based in the US.

The first e-commerce site provided positive feedback stating the proposal "it is aligned to solve some of the problems that we are facing i.e., different teams maintaining and deploying various parts of a web app."

The second e-commerce site indicated they view their entire site as a single product and would like a single service worker instance. They indicated multiple scopes and exclude lists would possibly be useful to restrict the service worker to disjoint sections of their product URL space.  This proposal meets most of these needs, but does not provide support for exclude lists.

## References & Acknowledgements

Note:  The service worker spec had [glob](https://en.wikipedia.org/wiki/Glob_(programming)) matching long ago and it was [removed](https://github.com/w3c/ServiceWorker/issues/287). At the time it was believed the exact match behavior was not necessary. Over time, however, it has become clear that there are sites that are having trouble fully adopting service workers since they cannot control their root origin URL without impacting all their various products hosted on sub-paths.

Note: [RFC 6570](https://tools.ietf.org/html/rfc6570) describes a URI templates system that includes the ability to perform some matching against URLs.  The RFC, however, [suggests](https://tools.ietf.org/html/rfc6570#section-1.4) it is not a good fit for general URL matching.

Note: [Early TAG Review](https://github.com/w3ctag/design-reviews/issues/417)

Other routing systems for flexibility comparison:

*   https://github.com/lukeed/regexparam
*   https://github.com/pillarjs/path-to-regexp/
*   https://edgeguides.rubyonrails.org/routing.html
*   https://stackoverflow.com/questions/14018215/what-is-the-significance-of-url-pattern-in-web-xml-and-how-to-configure-servlet (links to servlet spec pdf)
*   https://expressjs.com/en/guide/routing.html
*   http://nginx.org/en/docs/http/ngx_http_core_module.html?&_ga=2.193337709.1730038529.1565988792-1175143511.1565988792#location
*   https://reacttraining.com/react-router/web/api/Route

Contributions and review provided by:

* Łukasz Anforowicz
* Kenji Baheux
* L. David Baron
* Ralph Chelala
* Philip Chimento
* Kenneth Rohde Christiansen
* Victor Costan
* Domenic Denicola
* Matt Falkenhagen
* Matt Giuca
* Joe Gregorio
* Darwin Huang
* Rajesh Jagannathan
* Cyrus Kasaaian
* R. Samuel Klatchko
* Marijn Kruisselbrink
* Dominick Ng
* Kingsley Ngan
* Jeffrey Posnick
* Jimmy Shen
* Kinuko Yasuda

Special thanks to Jake Archibald for the [original idea](https://twitter.com/jaffathecake/status/1082331913128497152) to expose a URL matching primitive for use with service workers.
