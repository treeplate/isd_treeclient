
export 'platform_specific/stub.dart'
    if (dart.library.io) 'platform_specific/io.dart'
    if (dart.library.js_interop) 'platform_specific/web.dart';