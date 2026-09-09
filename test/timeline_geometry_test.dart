import 'package:flutter_test/flutter_test.dart';

import 'package:bazi_app/features/timeline/timeline_geometry.dart';

TimelineGeometry phone() =>
    TimelineGeometry.wholeLife(viewportWidth: 390, maxAge: 120);

void main() {
  group('pixel ↔ 虚岁 mapping', () {
    test('xForAge and ageForX are inverses', () {
      final g = phone().zoomBy(4, 200);
      for (final age in [0.0, 1.0, 37.5, 60.0, 119.0, 120.0]) {
        expect(g.ageForX(g.xForAge(age)), closeTo(age, 1e-9));
      }
    });

    test('age 0 sits at the left edge before any scrolling', () {
      expect(phone().xForAge(0), 0);
    });

    test('the whole life fits the viewport at the default zoom', () {
      final g = phone();
      expect(g.contentWidth, lessThanOrEqualTo(g.viewportWidth + 1e-9));
      expect(g.maxOffset, 0);
    });

    test('a narrow viewport falls back to the minimum zoom, not sub-pixel', () {
      // 120 years in 100 px would need 0.83 px/year, below the floor, so the
      // axis must become scrollable rather than illegible.
      final g = TimelineGeometry.wholeLife(viewportWidth: 100, maxAge: 120);
      expect(g.pxPerYear, TimelineGeometry.kMinPxPerYear);
      expect(g.maxOffset, greaterThan(0));
    });
  });

  group('panning', () {
    test('dragging left moves forward in life', () {
      final g = phone().zoomBy(8, 0);
      final before = g.visibleAges.$1;
      final after = g.panBy(-100).visibleAges.$1;
      expect(after, greaterThan(before));
    });

    test('cannot scroll before birth or past the end of the span', () {
      final g = phone().zoomBy(8, 0);
      expect(g.panBy(500).offset, 0);
      expect(g.panBy(-100000).offset, closeTo(g.maxOffset, 1e-9));
      final end = g.panBy(-100000);
      expect(end.ageForX(end.viewportWidth), closeTo(120, 1e-9));
    });

    test('nothing scrolls while the whole span fits', () {
      final g = phone();
      expect(g.panBy(-500).offset, 0);
    });
  });

  group('zooming', () {
    test('the age under the fingers stays under the fingers', () {
      var g = phone().zoomBy(6, 0).panBy(-300);
      const focalX = 150.0;
      final anchor = g.ageForX(focalX);
      g = g.zoomBy(1.7, focalX);
      expect(g.ageForX(focalX), closeTo(anchor, 1e-9));
    });

    test('zoom is clamped at both ends', () {
      expect(phone().zoomBy(1000, 0).pxPerYear, TimelineGeometry.kMaxPxPerYear);
      expect(
        phone().zoomBy(0.001, 0).pxPerYear,
        TimelineGeometry.kMinPxPerYear,
      );
    });

    test('zooming out re-clamps an offset that is now past the end', () {
      final zoomed = phone().zoomBy(20, 0).panBy(-1e6);
      final out = zoomed.zoomBy(0.05, 0);
      expect(out.offset, lessThanOrEqualTo(out.maxOffset + 1e-9));
    });
  });

  group('level of detail', () {
    test('the whole-life view on a phone is too dense for per-year ticks', () {
      final g = phone();
      expect(g.lod, TimelineLod.decade);
      expect(g.tickEvery, 10);
      expect(g.axisLabelEvery, 20);
    });

    test('detail rises with zoom and never skips a level', () {
      var g = phone();
      final seen = <TimelineLod>[g.lod];
      while (g.pxPerYear < TimelineGeometry.kMaxPxPerYear) {
        g = g.zoomBy(1.2, 0);
        if (g.lod != seen.last) seen.add(g.lod);
      }
      expect(seen, [
        TimelineLod.decade,
        TimelineLod.fiveYear,
        TimelineLod.year,
      ]);
    });
  });

  group('axis labels', () {
    test('never crowd closer than ~44 px at any zoom', () {
      var g = phone();
      while (true) {
        expect(
          g.axisLabelEvery * g.pxPerYear,
          greaterThanOrEqualTo(44.0),
          reason: 'at ${g.pxPerYear} px/year',
        );
        if (g.pxPerYear >= TimelineGeometry.kMaxPxPerYear) break;
        g = g.zoomBy(1.1, 0);
      }
    });

    test('are per-year only once a year is wide enough to hold one', () {
      final g = phone().zoomBy(1000, 0);
      expect(g.pxPerYear, TimelineGeometry.kMaxPxPerYear);
      expect(g.axisLabelEvery, 1);
    });
  });

  group('centering', () {
    test('an age in the middle of life lands mid-viewport', () {
      final g = phone().zoomBy(10, 0).centeredOn(60);
      expect(g.ageForX(g.viewportWidth / 2), closeTo(60, 1e-9));
    });

    test('centering near either end clamps instead of showing empty space', () {
      final g = phone().zoomBy(10, 0);
      expect(g.centeredOn(1).offset, 0);
      expect(g.centeredOn(120).offset, closeTo(g.maxOffset, 1e-9));
    });
  });

  group('visible range', () {
    test('is clamped to the span even when the viewport is wider', () {
      final g = phone();
      final (lo, hi) = g.visibleAges;
      expect(lo, 0);
      expect(hi, 120);
    });
  });
}
