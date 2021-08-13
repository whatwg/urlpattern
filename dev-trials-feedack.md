# URLPattern Dev Trials Feedback

Last updated: August 13, 2021


## Overview

The [Ready for Trial](https://groups.google.com/a/chromium.org/g/blink-dev/c/WitVII_BzyU/m/mI8lZY4NAgAJ) announcement was sent for the URLPattern on July 22.  To help spread awareness of the information and help developers try the API, we also did the following:



*   Published a [web.dev article](https://web.dev/urlpattern/).
*   Published [draft MDN documentation](https://github.com/WICG/urlpattern/blob/main/mdn-drafts/QUICK-REFERENCE.md).
*   Boosted with a [twitter thread](https://twitter.com/jeffposnick/status/1418245808563101701).
*   Ran a survey against a panel of web developers.

This post captures the feedback we have received to date regarding the URLPattern API.  [Additional feedback](https://github.com/WICG/urlpattern/issues/new) is still welcome, of course.

In general feedback has been positive.  The following sections provide some more detail.


## Survey Results

The survey gave us the opportunity to collect structured feedback from a panel of web developers.  This was an English language survey.

A summary of the results follows:



*   77% of respondents (n=247) were familiar with URL matching, with 42% actively using it.
*   80% of respondents (n=247) had a positive initial impression of the URLPattern API.  5% had a negative initial impression.
*   87% of respondents (n=180) felt the URLPattern API met their needs either fairly or very well.  Only 4% of respondents felt the API met their needs poorly.
*   75% of respondents (n=180) agreed they would use the URLPattern API if it shipped.
*   83% of respondents (n=180) agreed that integrating URLPattern API with other web APIs would make it easier for sites to use those other web APIs.
*   68% of respondents (n=180) indicated URLPattern support internationalization fairly or very well.  28% indicated they could not say.  Only 4% thought the API supported i18n poorly.  (Again, note that this was an English language survey which may skew the results on this question.)


## Specific Feedback

We have tried to capture specific feedback in the URLPattern Github [issues](https://github.com/WICG/urlpattern/issues).  We call out a selection of the significant issues here.

First, there were a couple of feature requests:



*   The most common piece of feedback across social media, the survey, and github has been a feature request to [support the generation of URL strings from a URLPattern and set of parameter values](https://github.com/WICG/urlpattern/issues/73).  This is similar to [path-to-regexp](https://github.com/pillarjs/path-to-regexp)'s `compile()` function.  Web developers use this feature to generate requests back to the server.  This technique has the benefit of encapsulating the URL structure in the pattern string so that the using code does not need to be aware of it.
*   One of the [vue](https://vuejs.org/) framework's authors has indicated they would need an [ordering of patterns](https://github.com/WICG/urlpattern/issues/61) in order to use the API.  This use case is bolstered by the fact that a popular server-side routing framework, [find-my-way](https://github.com/delvedor/find-my-way), also provides an ordering of routes.

These seem like worthwhile features to add, but we would like to tackle them after initially launching the matching capability.  Matching is useful on its own and is also a blocker for integration into some other web APIs like service worker scopes.

Second, there was some generalized feedback about [performance](https://github.com/WICG/urlpattern/issues/42) of URLPattern compared to the server-side framework [find-my-way](https://github.com/delvedor/find-my-way).  Initial investigations suggest URLPattern should be able to achieve most of the same optimizations.  We plan to do some additional performance investigation before launching the API.

Finally, at the end of 2020 an [issue](https://github.com/WICG/urlpattern/issues/43) was filed pointing out that `:foo` named parameters may not be friendly to right-to-left languages.  As part of this discussion we realized named parameters did not support unicode at the time.  That has been fixed and named parameters now support the same code points as javascript identifiers.

In regards to the RTL issue, however, so far we have decided to proceed with `:foo` style names.  We are doing this for a few reasons.  First, `:foo` names are well established across many different URL pattern matching systems; e.g. ruby on rails, etc.  This is a well lit path we are following from the industry and not something new we have introduced.

In addition, URLPattern API integrates these names into the result returned to javascript.  Javascript is a left-to-right language.  For example, javascript identifiers allow different code points in the left-hand "first" position compared to the rest of the identifier.  Since we want to integrate well with javascript it seems difficult to fully support an RTL name.

Further, there has been no follow-up from the original reporter or anyone else indicating that this is a problem or what an acceptable solution might look like.  We have also requested a w3c i18n review, but received no feedback.  Therefore, barring additional feedback, we plan to proceed with `:foo` names.
