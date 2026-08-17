{{flutter_js}}
{{flutter_build_config}}

(async () => {
  // The admin preview must always execute the freshly deployed renderer.
  // Older Flutter builds may have registered a service worker even though the
  // current build disables PWA support, which otherwise leaves stale theme
  // parsing code active inside the iframe.
  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(
      registrations
        .filter((registration) =>
          registration.scope.includes('/flutter-preview/'))
        .map((registration) => registration.unregister()),
    );
  }

  if ('caches' in window) {
    const cacheNames = await caches.keys();
    await Promise.all(
      cacheNames
        .filter((name) => name.toLowerCase().includes('flutter'))
        .map((name) => caches.delete(name)),
    );
  }

  const currentBuild = _flutter.buildConfig.builds[0];
  currentBuild.mainJsPath = `main.dart.js?v=${Date.now()}`;
  _flutter.loader.load();
})();
