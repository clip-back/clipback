{{flutter_js}}
{{flutter_build_config}}

if (window.location.hostname === 'localhost') {
  for (const build of _flutter.buildConfig.builds) {
    if (build.mainJsPath) {
      build.mainJsPath = `${build.mainJsPath}?v=${Date.now()}`;
    }
  }
}

_flutter.loader.load();
