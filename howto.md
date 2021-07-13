# How to use the URLPattern API

The URLPattern API is currently available in Chrome 93 and later behind a flag.

1. Download Chrome ([Android](https://play.google.com/store/apps/details?id=com.android.chrome), [Desktop](https://www.google.com/chrome/)).
2. Navigate to `chrome://flags` and enable `Experimental Web Platform features`.
3. Visit a page that uses `URLPattern`, such as the [demo on glitch](https://urlpattern-sw-routing.glitch.me/).

Here is an example of how to use the API:

```javascript
const pattern = new URLPattern({ pathname: '/:product/index.html' });
const result = pattern.exec(someURL);
if (result) {
  handleProduct(result.pathname.groups.product);
}
```

More code examples can be found in the [URLPattern documentation](docs/urlpattern.md).
