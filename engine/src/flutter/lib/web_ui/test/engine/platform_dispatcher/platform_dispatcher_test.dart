// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;
import 'package:ui/ui_web/src/ui_web.dart' as ui_web;

import '../../common/test_initialization.dart';
import '../semantics/semantics_tester.dart';

EngineSemantics semantics() => EngineSemantics.instance;
EngineSemanticsOwner owner() => EnginePlatformDispatcher.instance.implicitView!.semantics;

/// Creates a DOM mouse event with fractional coordinates to avoid triggering
/// assistive technology detection logic.
///
/// The platform dispatcher's _isIntegerCoordinateNavigation() method detects
/// assistive technology clicks by checking for integer coordinates. Tests
/// should use fractional coordinates to simulate normal user clicks.
DomMouseEvent createTestClickEvent({
  double clientX = 1.5,
  double clientY = 1.5,
  bool bubbles = true,
}) {
  return createDomMouseEvent('click', <String, Object>{
    'clientX': clientX,
    'clientY': clientY,
    'bubbles': bubbles,
  });
}

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

void testMain() {
  group('PlatformDispatcher', () {
    late EnginePlatformDispatcher dispatcher;

    setUpAll(() async {
      await bootstrapAndRunApp(withImplicitView: true);
    });

    setUp(() {
      dispatcher = EnginePlatformDispatcher();
    });

    tearDown(() {
      dispatcher.dispose();
    });

    test('reports at least one display', () {
      expect(ui.PlatformDispatcher.instance.displays.length, greaterThan(0));
    });

    test('high contrast in accessibilityFeatures has the correct value', () {
      final MockHighContrastSupport mockHighContrast = MockHighContrastSupport();
      HighContrastSupport.instance = mockHighContrast;

      final EnginePlatformDispatcher dispatcher = EnginePlatformDispatcher();

      expect(dispatcher.accessibilityFeatures.highContrast, isTrue);
      mockHighContrast.isEnabled = false;
      mockHighContrast.invokeListeners(mockHighContrast.isEnabled);
      expect(dispatcher.accessibilityFeatures.highContrast, isFalse);

      dispatcher.dispose();
    });

    test('AppLifecycleState transitions through all states', () {
      final List<ui.AppLifecycleState> states = <ui.AppLifecycleState>[];
      void listener(ui.AppLifecycleState state) {
        states.add(state);
      }

      final MockAppLifecycleState mockAppLifecycleState = MockAppLifecycleState();

      expect(mockAppLifecycleState.appLifecycleState, ui.AppLifecycleState.resumed);

      mockAppLifecycleState.addListener(listener);
      expect(mockAppLifecycleState.activeCallCount, 1);

      expect(states, equals(<ui.AppLifecycleState>[ui.AppLifecycleState.resumed]));

      mockAppLifecycleState.inactive();
      expect(mockAppLifecycleState.appLifecycleState, ui.AppLifecycleState.inactive);
      expect(
        states,
        equals(<ui.AppLifecycleState>[ui.AppLifecycleState.resumed, ui.AppLifecycleState.inactive]),
      );

      // consecutive same states are skipped
      mockAppLifecycleState.inactive();
      expect(
        states,
        equals(<ui.AppLifecycleState>[ui.AppLifecycleState.resumed, ui.AppLifecycleState.inactive]),
      );

      mockAppLifecycleState.hidden();
      expect(mockAppLifecycleState.appLifecycleState, ui.AppLifecycleState.hidden);
      expect(
        states,
        equals(<ui.AppLifecycleState>[
          ui.AppLifecycleState.resumed,
          ui.AppLifecycleState.inactive,
          ui.AppLifecycleState.hidden,
        ]),
      );

      mockAppLifecycleState.resume();
      expect(mockAppLifecycleState.appLifecycleState, ui.AppLifecycleState.resumed);
      expect(
        states,
        equals(<ui.AppLifecycleState>[
          ui.AppLifecycleState.resumed,
          ui.AppLifecycleState.inactive,
          ui.AppLifecycleState.hidden,
          ui.AppLifecycleState.resumed,
        ]),
      );

      mockAppLifecycleState.detach();
      expect(mockAppLifecycleState.appLifecycleState, ui.AppLifecycleState.detached);
      expect(
        states,
        equals(<ui.AppLifecycleState>[
          ui.AppLifecycleState.resumed,
          ui.AppLifecycleState.inactive,
          ui.AppLifecycleState.hidden,
          ui.AppLifecycleState.resumed,
          ui.AppLifecycleState.detached,
        ]),
      );

      mockAppLifecycleState.removeListener(listener);
      expect(mockAppLifecycleState.deactivateCallCount, 1);

      // No more states should be recorded after the listener is removed.
      mockAppLifecycleState.resume();
      expect(
        states,
        equals(<ui.AppLifecycleState>[
          ui.AppLifecycleState.resumed,
          ui.AppLifecycleState.inactive,
          ui.AppLifecycleState.hidden,
          ui.AppLifecycleState.resumed,
          ui.AppLifecycleState.detached,
        ]),
      );
    });

    test('responds to flutter/skia Skia.setResourceCacheMaxBytes', () async {
      const MethodCodec codec = JSONMethodCodec();
      final Completer<ByteData?> completer = Completer<ByteData?>();
      ui.PlatformDispatcher.instance.sendPlatformMessage(
        'flutter/skia',
        codec.encodeMethodCall(
          const MethodCall('Skia.setResourceCacheMaxBytes', 512 * 1000 * 1000),
        ),
        completer.complete,
      );

      final ByteData? response = await completer.future;
      expect(response, isNotNull);
      expect(codec.decodeEnvelope(response!), <bool>[true]);
    });

    test('responds to flutter/platform HapticFeedback.vibrate', () async {
      const MethodCodec codec = JSONMethodCodec();
      final Completer<ByteData?> completer = Completer<ByteData?>();
      ui.PlatformDispatcher.instance.sendPlatformMessage(
        'flutter/platform',
        codec.encodeMethodCall(const MethodCall('HapticFeedback.vibrate')),
        completer.complete,
      );

      final ByteData? response = await completer.future;
      expect(response, isNotNull);
      expect(codec.decodeEnvelope(response!), true);
    });

    test('responds to flutter/platform SystemChrome.setSystemUIOverlayStyle', () async {
      const MethodCodec codec = JSONMethodCodec();
      final Completer<ByteData?> completer = Completer<ByteData?>();
      ui.PlatformDispatcher.instance.sendPlatformMessage(
        'flutter/platform',
        codec.encodeMethodCall(
          const MethodCall('SystemChrome.setSystemUIOverlayStyle', <String, dynamic>{}),
        ),
        completer.complete,
      );

      final ByteData? response = await completer.future;
      expect(response, isNotNull);
      expect(codec.decodeEnvelope(response!), true);
    });

    test('responds to flutter/contextmenu enable', () async {
      const MethodCodec codec = JSONMethodCodec();
      final Completer<ByteData?> completer = Completer<ByteData?>();
      ui.PlatformDispatcher.instance.sendPlatformMessage(
        'flutter/contextmenu',
        codec.encodeMethodCall(const MethodCall('enableContextMenu')),
        completer.complete,
      );

      final ByteData? response = await completer.future;
      expect(response, isNotNull);
      expect(codec.decodeEnvelope(response!), true);
    });

    test('responds to flutter/contextmenu disable', () async {
      const MethodCodec codec = JSONMethodCodec();
      final Completer<ByteData?> completer = Completer<ByteData?>();
      ui.PlatformDispatcher.instance.sendPlatformMessage(
        'flutter/contextmenu',
        codec.encodeMethodCall(const MethodCall('disableContextMenu')),
        completer.complete,
      );

      final ByteData? response = await completer.future;
      expect(response, isNotNull);
      expect(codec.decodeEnvelope(response!), true);
    });

    test('can find text scale factor', () async {
      const double deltaTolerance = 1e-5;

      final DomElement root = domDocument.documentElement!;
      final String oldFontSize = root.style.fontSize;

      addTearDown(() {
        root.style.fontSize = oldFontSize;
      });

      root.style.fontSize = '16px';
      expect(findBrowserTextScaleFactor(), 1.0);

      root.style.fontSize = '20px';
      expect(findBrowserTextScaleFactor(), 1.25);

      root.style.fontSize = '24px';
      expect(findBrowserTextScaleFactor(), 1.5);

      root.style.fontSize = '14.4px';
      expect(findBrowserTextScaleFactor(), closeTo(0.9, deltaTolerance));

      root.style.fontSize = '12.8px';
      expect(findBrowserTextScaleFactor(), closeTo(0.8, deltaTolerance));

      root.style.fontSize = '';
      expect(findBrowserTextScaleFactor(), 1.0);
    });

    test("calls onTextScaleFactorChanged when the <html> element's font-size changes", () async {
      final DomElement root = domDocument.documentElement!;
      final String oldFontSize = root.style.fontSize;
      final ui.VoidCallback? oldCallback = ui.PlatformDispatcher.instance.onTextScaleFactorChanged;

      addTearDown(() {
        root.style.fontSize = oldFontSize;
        ui.PlatformDispatcher.instance.onTextScaleFactorChanged = oldCallback;
      });

      root.style.fontSize = '16px';

      bool isCalled = false;
      ui.PlatformDispatcher.instance.onTextScaleFactorChanged = () {
        isCalled = true;
      };

      root.style.fontSize = '20px';
      await Future<void>.delayed(Duration.zero);
      expect(root.style.fontSize, '20px');
      expect(isCalled, isTrue);
      expect(ui.PlatformDispatcher.instance.textScaleFactor, findBrowserTextScaleFactor());

      isCalled = false;

      root.style.fontSize = '16px';
      await Future<void>.delayed(Duration.zero);
      expect(root.style.fontSize, '16px');
      expect(isCalled, isTrue);
      expect(ui.PlatformDispatcher.instance.textScaleFactor, findBrowserTextScaleFactor());
    });

    test('disposes all its views', () {
      final EngineFlutterView view1 = EngineFlutterView(dispatcher, createDomHTMLDivElement());
      final EngineFlutterView view2 = EngineFlutterView(dispatcher, createDomHTMLDivElement());
      final EngineFlutterView view3 = EngineFlutterView(dispatcher, createDomHTMLDivElement());

      dispatcher.viewManager
        ..registerView(view1)
        ..registerView(view2)
        ..registerView(view3);

      expect(view1.isDisposed, isFalse);
      expect(view2.isDisposed, isFalse);
      expect(view3.isDisposed, isFalse);

      dispatcher.dispose();
      expect(view1.isDisposed, isTrue);
      expect(view2.isDisposed, isTrue);
      expect(view3.isDisposed, isTrue);
    });

    test('connects view disposal to metrics changed event', () {
      final EngineFlutterView view1 = EngineFlutterView(dispatcher, createDomHTMLDivElement());
      final EngineFlutterView view2 = EngineFlutterView(dispatcher, createDomHTMLDivElement());

      dispatcher.viewManager
        ..registerView(view1)
        ..registerView(view2);

      expect(view1.isDisposed, isFalse);
      expect(view2.isDisposed, isFalse);

      bool onMetricsChangedCalled = false;
      dispatcher.onMetricsChanged = () {
        onMetricsChangedCalled = true;
      };

      expect(onMetricsChangedCalled, isFalse);

      dispatcher.viewManager.disposeAndUnregisterView(view2.viewId);

      expect(onMetricsChangedCalled, isTrue, reason: 'onMetricsChanged should have been called.');

      dispatcher.dispose();
    });

    test('disconnects view disposal event on dispose', () {
      final EngineFlutterView view1 = EngineFlutterView(dispatcher, createDomHTMLDivElement());

      dispatcher.viewManager.registerView(view1);

      expect(view1.isDisposed, isFalse);

      bool onMetricsChangedCalled = false;
      dispatcher.onMetricsChanged = () {
        onMetricsChangedCalled = true;
      };

      dispatcher.dispose();

      expect(onMetricsChangedCalled, isFalse);
      expect(view1.isDisposed, isTrue);
    });

    test('invokeOnViewFocusChange calls onViewFocusChange', () {
      final List<ui.ViewFocusEvent> dispatchedViewFocusEvents = <ui.ViewFocusEvent>[];
      const ui.ViewFocusEvent viewFocusEvent = ui.ViewFocusEvent(
        viewId: 0,
        state: ui.ViewFocusState.focused,
        direction: ui.ViewFocusDirection.undefined,
      );

      dispatcher.onViewFocusChange = dispatchedViewFocusEvents.add;
      dispatcher.invokeOnViewFocusChange(viewFocusEvent);

      expect(dispatchedViewFocusEvents, hasLength(1));
      expect(dispatchedViewFocusEvents.single, viewFocusEvent);
    });

    test('invokeOnViewFocusChange preserves the zone', () {
      final Zone zone1 = Zone.current.fork();
      final Zone zone2 = Zone.current.fork();
      const ui.ViewFocusEvent viewFocusEvent = ui.ViewFocusEvent(
        viewId: 0,
        state: ui.ViewFocusState.focused,
        direction: ui.ViewFocusDirection.undefined,
      );

      zone1.runGuarded(() {
        dispatcher.onViewFocusChange = (_) {
          expect(Zone.current, zone1);
        };
      });

      zone2.runGuarded(() {
        dispatcher.invokeOnViewFocusChange(viewFocusEvent);
      });
    });

    test('adds the accesibility placeholder', () {
      expect(dispatcher.accessibilityPlaceholder.isConnected, isTrue);
      expect(domDocument.body!.children.first, dispatcher.accessibilityPlaceholder);
    });

    test('removes the accesibility placeholder', () {
      dispatcher.dispose();
      expect(dispatcher.accessibilityPlaceholder.isConnected, isFalse);
    });

    test('scheduleWarmupFrame should call both callbacks', () async {
      bool beginFrameCalled = false;
      final Completer<void> drawFrameCalled = Completer<void>();
      dispatcher.scheduleWarmUpFrame(
        beginFrame: () {
          expect(drawFrameCalled.isCompleted, false);
          expect(beginFrameCalled, false);
          beginFrameCalled = true;
        },
        drawFrame: () {
          expect(beginFrameCalled, true);
          expect(drawFrameCalled.isCompleted, false);
          drawFrameCalled.complete();
        },
      );
      await drawFrameCalled.future;
      expect(beginFrameCalled, true);
      expect(drawFrameCalled.isCompleted, true);
    });

    group('NavigationTarget', () {
      test('creates with element and nodeId', () {
        final DomElement element = createDomHTMLDivElement();
        const int nodeId = 123;

        final NavigationTarget target = NavigationTarget(element, nodeId);

        expect(target.element, equals(element));
        expect(target.nodeId, equals(nodeId));
      });
    });

    group('AT Focus Handler Integration', () {
      test('navigation focus handler is registered during initialization', () {
        final DomElement navButton = createDomHTMLButtonElement();
        navButton.setAttribute('id', '${kFlutterSemanticNodePrefix}123');
        navButton.setAttribute('role', 'button');
        navButton.tabIndex = 0;
        domDocument.body!.append(navButton);

        addTearDown(() {
          navButton.remove();
        });

        final DomMouseEvent atClickEvent = createDomMouseEvent('click', <String, Object>{
          'clientX': 0,
          'clientY': 0,
          'bubbles': true,
        });

        navButton.dispatchEvent(atClickEvent);

        expect(navButton.isConnected, isTrue);
      });

      test('does not interfere with normal click events', () {
        final DomElement navButton = createDomHTMLButtonElement();
        navButton.setAttribute('id', '${kFlutterSemanticNodePrefix}456');
        navButton.setAttribute('role', 'button');
        navButton.tabIndex = 0;
        domDocument.body!.append(navButton);

        addTearDown(() {
          navButton.remove();
        });

        final DomMouseEvent normalClickEvent = createDomMouseEvent('click', <String, Object>{
          'clientX': 150.5,
          'clientY': 200.7,
          'bubbles': true,
        });

        navButton.dispatchEvent(normalClickEvent);

        expect(navButton.isConnected, isTrue);
      });

      test('handles events from multiple navigation element types', () {
        final List<DomElement> navElements = <DomElement>[
          createDomHTMLButtonElement()..setAttribute('role', 'button'),
          createDomElement('a')..setAttribute('role', 'link'),
          createDomHTMLDivElement()..setAttribute('role', 'tab'),
        ];

        for (int i = 0; i < navElements.length; i++) {
          final DomElement element = navElements[i];
          element.setAttribute('id', '$kFlutterSemanticNodePrefix${100 + i}');
          element.tabIndex = 0;
          domDocument.body!.append(element);
        }

        addTearDown(() {
          for (final DomElement element in navElements) {
            element.remove();
          }
        });

        for (final DomElement element in navElements) {
          final DomMouseEvent atEvent = createTestClickEvent();

          expect(() => element.dispatchEvent(atEvent), returnsNormally);
        }
      });

      test('properly manages focus state detection', () {
        final DomElement navButton = createDomHTMLButtonElement();
        navButton.setAttribute('id', '${kFlutterSemanticNodePrefix}999');
        navButton.setAttribute('role', 'button');
        navButton.tabIndex = 0;
        domDocument.body!.append(navButton);

        addTearDown(() {
          navButton.remove();
        });

        final DomMouseEvent atEvent = createTestClickEvent(clientX: 0.5, clientY: 0.5);

        expect(() => navButton.dispatchEvent(atEvent), returnsNormally);
        expect(navButton.isConnected, isTrue);
      });

      test('handles elements with semantics focus action but no tabindex', () {
        semantics().semanticsEnabled = true;

        final SemanticsTester tester = SemanticsTester(owner());
        tester.updateNode(
          id: 0,
          children: <SemanticsNodeUpdate>[
            tester.updateNode(id: 500, rect: const ui.Rect.fromLTRB(0, 0, 100, 50), hasFocus: true),
          ],
        );
        final Map<int, SemanticsObject> tree = tester.apply();

        final SemanticsObject semanticsObject = tree[500]!;
        final DomElement focusableElement = semanticsObject.element;

        focusableElement.removeAttribute('tabindex');

        domDocument.body!.append(focusableElement);

        addTearDown(() {
          focusableElement.remove();
          semantics().semanticsEnabled = false;
        });

        final DomMouseEvent atEvent = createTestClickEvent();

        expect(() => focusableElement.dispatchEvent(atEvent), returnsNormally);
        expect(focusableElement.isConnected, isTrue);
      });

      test('prioritizes tabindex over semantics focus action for focus finding', () {
        semantics().semanticsEnabled = true;

        final SemanticsTester tester = SemanticsTester(owner());
        tester.updateNode(
          id: 0,
          children: <SemanticsNodeUpdate>[
            tester.updateNode(id: 600, rect: const ui.Rect.fromLTRB(0, 0, 100, 50), hasFocus: true),
          ],
        );
        final Map<int, SemanticsObject> tree = tester.apply();

        final SemanticsObject semanticsObject = tree[600]!;
        final DomElement elementWithBoth = semanticsObject.element;
        elementWithBoth.tabIndex = 0;
        domDocument.body!.append(elementWithBoth);

        addTearDown(() {
          elementWithBoth.remove();
          semantics().semanticsEnabled = false;
        });

        final DomMouseEvent atEvent = createTestClickEvent(clientX: 0.5, clientY: 0.5);

        expect(() => elementWithBoth.dispatchEvent(atEvent), returnsNormally);
        expect(elementWithBoth.isConnected, isTrue);
        expect(elementWithBoth.tabIndex, equals(0));
      });

      test('finds child elements with semantics focus action', () {
        semantics().semanticsEnabled = true;

        final SemanticsTester tester = SemanticsTester(owner());
        tester.updateNode(
          id: 0,
          children: <SemanticsNodeUpdate>[
            tester.updateNode(id: 700, rect: const ui.Rect.fromLTRB(0, 0, 100, 50), hasFocus: true),
          ],
        );
        final Map<int, SemanticsObject> tree = tester.apply();

        final SemanticsObject semanticsObject = tree[700]!;
        final DomElement childElement = semanticsObject.element;

        childElement.removeAttribute('tabindex');

        final DomElement parentElement = createDomHTMLDivElement();
        parentElement.append(childElement);
        domDocument.body!.append(parentElement);

        addTearDown(() {
          parentElement.remove();
          semantics().semanticsEnabled = false;
        });

        final DomMouseEvent atEvent = createTestClickEvent();

        expect(() => parentElement.dispatchEvent(atEvent), returnsNormally);
        expect(parentElement.isConnected, isTrue);
        expect(childElement.isConnected, isTrue);
      });
    });
  }, skip: ui_web.browser.isFirefox);
}

class MockHighContrastSupport implements HighContrastSupport {
  bool isEnabled = true;

  final List<HighContrastListener> _listeners = <HighContrastListener>[];

  @override
  bool get isHighContrastEnabled => isEnabled;

  void invokeListeners(bool val) {
    for (final HighContrastListener listener in _listeners) {
      listener(val);
    }
  }

  @override
  void addListener(HighContrastListener listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(HighContrastListener listener) {
    _listeners.remove(listener);
  }
}

class MockAppLifecycleState extends AppLifecycleState {
  int activeCallCount = 0;
  int deactivateCallCount = 0;

  void detach() {
    onAppLifecycleStateChange(ui.AppLifecycleState.detached);
  }

  void resume() {
    onAppLifecycleStateChange(ui.AppLifecycleState.resumed);
  }

  void inactive() {
    onAppLifecycleStateChange(ui.AppLifecycleState.inactive);
  }

  void hidden() {
    onAppLifecycleStateChange(ui.AppLifecycleState.hidden);
  }

  @override
  void activate() {
    activeCallCount++;
  }

  @override
  void deactivate() {
    deactivateCallCount++;
  }
}
