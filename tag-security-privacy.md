# TAG Security & Privacy Questionnaire Answers #

* **Author:** wanderview@google.com
* **Questionnaire Source:** https://www.w3.org/TR/security-privacy-questionnaire/#questions

## Questions ##

* **What information might this feature expose to Web sites or other parties, and for what purposes is that exposure necessary?**
  * None.  The proposal relates to matching client URLs that are already exposed to sites.
* **Is this specification exposing the minimum amount of information necessary to power the feature?**
  * Yes.  It does not expose any new information.
* **How does this specification deal with personal information or personally-identifiable information or information derived thereof?**
  * This proposal does not deal with PII.
* **How does this specification deal with sensitive information?**
  * No.
* **Does this specification introduce new state for an origin that persists across browsing sessions?**
  * No.  It allows a pattern to be stored in the existing service worker scope persistent state.  Sites could previously store arbitrary data in this field using URL encoding.
* **What information from the underlying platform, e.g. configuration data, is exposed by this specification to an origin?**
  * None.
* **Does this specification allow an origin access to sensors on a user’s device**
  * No.
* **What data does this specification expose to an origin? Please also document what data is identical to data exposed by other features, in the same or different contexts.**
  * None.
* **Does this specification enable new script execution/loading mechanisms?**
  * It allows service worker scopes to match more restrictive URL patterns.  It also supports matching URL search parameters regardless of order.  This allows a service worker to be reliably spawned in cases where it could not before.
* **Does this specification allow an origin to access other devices?**
  * No.
* **Does this specification allow an origin some measure of control over a user agent’s native UI?**
  * No.
* **What temporary identifiers might this this specification create or expose to the web?**
  * None.
* **How does this specification distinguish between behavior in first-party and third-party contexts?**
  * Service workers operate differently in first-party and third-party contexts in some browsers; e.g. double-keying, etc.  This proposal does not change that behavior or create new differences.
* **How does this specification work in the context of a user agent’s Private \ Browsing or "incognito" mode?**
  * Service workers operate differently in private browser modes in some browsers; e.g. firefox does not support SW in private browsing.  This proposal does not change that behavior or create new differences.
* **Does this specification have a "Security Considerations" and "Privacy Considerations" section?**
  * Yes.
* **Does this specification allow downgrading default security characteristics?**
  * No.
