# Gufi — Performance & Zero-Jank Engineering Principles

This document establishes the permanent performance rules for the Gufi codebase. Every engineer and AI agent contributing to Gufi must adhere strictly to these principles before shipping any feature or milestone.

---

## 1. 120Hz Target & Frame Budget
- **Target**: 120Hz-capable rendering on supported high-refresh hardware (e.g. ProMotion displays).
- **Frame Budget**: **≈ 8.33ms per frame** (UI thread work + Raster thread work combined).
- Flutter/device hardware scheduling drives rendering; frame callbacks must finish comfortably inside 8.33ms with headroom.

---

## 2. Navigation & Tap Latency
- **Instant Tap Response**:
  - Pointer down: subtle micro-scale (`0.985`, ~70–90ms).
  - Pointer release: spring back (`1.0`, ~90–110ms).
- **Zero Artificial Delays**:
  - Never use `Future.delayed()`, `Timer()`, or artificial loading spinners before initiating local screen navigation.
  - Transitions must begin immediately on tap.
- **Lightweight Route Transitions**:
  - Duration: ~160–180ms.
  - Incoming page: opacity `0 -> 1`, subtle horizontal translate (`~6–10px -> 0`).
  - Outgoing page: geometrically frozen and stable (no jumping, shrinking, or unintended layout recalculations).

---

## 3. Layout Stability & Keyboard Rules
- **No Layout Jumps**:
  - Screens without text inputs (e.g., Welcome / Landing) must set `resizeToAvoidBottomInset: false` and ignore bottom insets so opening keyboards in pushed routes never causes outgoing screens to compress or jump.
  - Breakpoints must be based on device dimensions (`MediaQuery.sizeOf(context).height`) rather than dynamic viewport heights that shrink with keyboards.
- **Button Dimension Preservation**:
  - When transitioning to a loading state, button width, height, and surrounding padding must remain strictly fixed (no layout shift).

---

## 4. Rebuild & Repaint Discipline
- **Minimal Rebuild Scope**:
  - Never rebuild an entire `Scaffold` or screen hierarchy for local state changes (e.g., `PopScope` or local can-pop status). Use scoped `ValueListenableBuilder`, small widgets, and Riverpod `select()`.
  - Use `const` constructors wherever possible for static subtrees.
- **Repaint Boundaries**:
  - Isolate repainting for frequently changing or animated indicators. Do not scatter `RepaintBoundary` blindly—apply where profiling shows raster savings.
- **Avoid Heavy Raster Costs**:
  - Avoid gratuitous `BackdropFilter`, stacked translucent blurs, heavy shader masks, or complex `CustomPainter` loops without verified profiling.

---

## 5. Lifecycle & Resource Ownership
- **Single Ownership & Clean Disposal**:
  - Every `AnimationController`, `Ticker`, `Timer`, `ScrollController`, `PageController`, `FocusNode`, `TextEditingController`, and `StreamSubscription` must be initialized once and disposed cleanly.
  - Never create or reinitialize controllers inside `build()`.
  - One-time entrance animations must run once and never restart due to parent rebuilds or local navigation taps.

---

## 6. Asynchronous Backend & Non-Blocking UI
- **UI Thread Stays Free**:
  - Network requests, database transformations, authentication flows, verification calls, and JSON processing must never block the UI isolate.
  - UI provides immediate optimistic or responsive feedback; asynchronous work proceeds concurrently.

---

## 7. Memory & Image Efficiency
- **Image Decoding**:
  - Decode images near their display dimensions using `cacheWidth` and `cacheHeight`.
  - Never hold full-resolution uncompressed assets in memory for small avatars or icons.
- **Leak Prevention**:
  - Push/pop cycles (e.g., Onboarding → Welcome → Auth → Back) repeated 30–50 times must settle to a constant memory floor without retained controllers, listeners, or screens.

---

## 8. Performance Regression Gate
After EVERY substantial feature implementation:
1. `flutter analyze` — 0 issues.
2. Clean dead code, unused test UI, and obsolete files.
3. Inspect unnecessary widget rebuilds.
4. Verify controller/listener disposal.
5. Test navigation and keyboard behaviors.
6. Smoke test in **Profile mode** with DevTools.
7. Smoke test in **Release mode** on the physical iPhone.
