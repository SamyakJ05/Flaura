# Flaura LiteRT mobile fork

This is a source-controlled mobile fork of `flutter_litert` 3.7.0. Flaura uses
the stable `Interpreter` API, not the package's optional LiteRT Next
`CompiledModel` API.

The iOS package manifest therefore excludes `LiteRt.framework` and
`LiteRtMetalAccelerator.framework`. Those two optional frameworks ship duplicate
Objective-C classes together on device, which produces runtime warnings and can
cause instability. The TensorFlow Lite C runtime and its Metal/Core ML delegates
remain available for Flaura's Interpreter inference on iOS and Android.
