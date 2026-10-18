// Date and time pickers: the textual field with parts (and its stepper), the graphical
// calendar and the clock face.
//
// Measured: the time field with parts, the focused part filled with the accent (clock.md ›
// Alarms, orange `#c87524` in Clock, whose accent is orange); the textual date picker 24 pt tall
// with its stepper; the graphical calendar 139 × 148, a month header with ◀ ● ▶, Monday-first
// grid, today in the accent's text color, the selected day a gray square (CT-DP-02, INV-B
// gallery). Provisional: the cell size (22 pt), the square's gray and radius, the field metrics
// (the text field ones), the clock face (120 pt, hands 1.5 / 1 pt).

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'input_style.dart';
import 'stepper.dart';
import 'text_field.dart' show FieldBox;
import '../../appearance.dart';

/// What a date field shows.
enum DateFieldMode { date, time, dateAndTime }

/// A part of a date field.
enum DatePart { day, month, year, hour, minute, second, dayPeriod }

/// The texts of the date pickers, given by the app in its language.
@immutable
class DatePickerLabels {
  const DatePickerLabels({
    this.monthNames = const [],
    this.weekdayInitials = const [],
    this.am = 'AM',
    this.pm = 'PM',
    this.previousMonth,
    this.nextMonth,
    this.today,
  });

  /// January to December.
  final List<String> monthNames;

  /// Sunday to Saturday, one or two letters.
  final List<String> weekdayInitials;

  /// The day period of a 12-hour clock.
  final String am;
  final String pm;

  /// Accessibility labels of the calendar buttons.
  final String? previousMonth;
  final String? nextMonth;
  final String? today;
}

/// The order of the date parts and the separator for a locale: month first in the United
/// States, day first elsewhere; year first in East Asian locales.
List<DatePart> datePartOrder(Locale? locale) {
  final lang = locale?.languageCode;
  final country = locale?.countryCode;
  if (lang == 'en' && (country == null || country == 'US')) {
    return const [DatePart.month, DatePart.day, DatePart.year];
  }
  if (lang == 'zh' || lang == 'ja' || lang == 'ko' || lang == 'hu') {
    return const [DatePart.year, DatePart.month, DatePart.day];
  }
  return const [DatePart.day, DatePart.month, DatePart.year];
}

/// A date and time field with parts: ←/→ choose a part, ↑/↓ change it, digits type it.
/// With [stepper] a stepper on the right changes the focused part.
class SilicaDateField extends StatefulWidget {
  const SilicaDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.mode = DateFieldMode.date,
    this.labels = const DatePickerLabels(),
    this.use24Hour = true,
    this.seconds = false,
    this.stepper = false,
    this.enabled = true,
    this.accent,
    this.order,
    this.focusNode,
    this.semanticLabel,
    this.fontSize = InputMetrics.fontSize,
  });

  final DateTime value;
  final ValueChanged<DateTime>? onChanged;
  final DateFieldMode mode;
  final DatePickerLabels labels;
  final bool use24Hour;
  final bool seconds;
  final bool stepper;
  final bool enabled;

  /// The fill of the focused part; the accent when null (Clock passes its orange).
  final Color? accent;

  /// The date part order; from the locale when null.
  final List<DatePart>? order;
  final FocusNode? focusNode;
  final String? semanticLabel;

  /// The digits size (Clock's alarm time is large).
  final double fontSize;

  @override
  State<SilicaDateField> createState() => _SilicaDateFieldState();
}

class _SilicaDateFieldState extends State<SilicaDateField> {
  FocusNode? _ownFocus;
  int _part = 0;
  String _typed = '';

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
  bool get _enabled => widget.enabled && widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _focusChanged() => setState(() => _typed = '');

  List<DatePart> _parts(BuildContext context) {
    final date =
        widget.order ?? datePartOrder(Localizations.maybeLocaleOf(context));
    final time = [
      DatePart.hour,
      DatePart.minute,
      if (widget.seconds) DatePart.second,
      if (!widget.use24Hour) DatePart.dayPeriod,
    ];
    return switch (widget.mode) {
      DateFieldMode.date => date,
      DateFieldMode.time => time,
      DateFieldMode.dateAndTime => [...date, ...time],
    };
  }

  String _text(DatePart part) {
    final v = widget.value;
    String two(int n) => n.toString().padLeft(2, '0');
    return switch (part) {
      DatePart.day => two(v.day),
      DatePart.month => two(v.month),
      DatePart.year => v.year.toString().padLeft(4, '0'),
      DatePart.hour =>
        widget.use24Hour ? two(v.hour) : '${(v.hour + 11) % 12 + 1}',
      DatePart.minute => two(v.minute),
      DatePart.second => two(v.second),
      DatePart.dayPeriod => v.hour < 12 ? widget.labels.am : widget.labels.pm,
    };
  }

  static int _daysIn(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  DateTime _with(DatePart part, int value) {
    final v = widget.value;
    int wrap(int x, int lo, int hi) => lo + (x - lo) % (hi - lo + 1);
    var year = v.year, month = v.month, day = v.day;
    var hour = v.hour, minute = v.minute, second = v.second;
    switch (part) {
      case DatePart.day:
        day = wrap(value, 1, _daysIn(year, month));
      case DatePart.month:
        month = wrap(value, 1, 12);
      case DatePart.year:
        year = value.clamp(1, 9999);
      case DatePart.hour:
        hour = wrap(value, 0, 23);
      case DatePart.minute:
        minute = wrap(value, 0, 59);
      case DatePart.second:
        second = wrap(value, 0, 59);
      case DatePart.dayPeriod:
        hour = (hour + 12) % 24;
    }
    day = math.min(day, _daysIn(year, month));
    return v.isUtc
        ? DateTime.utc(year, month, day, hour, minute, second)
        : DateTime(year, month, day, hour, minute, second);
  }

  int _get(DatePart part) {
    final v = widget.value;
    return switch (part) {
      DatePart.day => v.day,
      DatePart.month => v.month,
      DatePart.year => v.year,
      DatePart.hour => v.hour,
      DatePart.minute => v.minute,
      DatePart.second => v.second,
      DatePart.dayPeriod => v.hour < 12 ? 0 : 1,
    };
  }

  void _stepPart(List<DatePart> parts, int direction) {
    final part = parts[_part.clamp(0, parts.length - 1)];
    _typed = '';
    widget.onChanged?.call(_with(part, _get(part) + direction));
  }

  void _type(List<DatePart> parts, String digit) {
    final part = parts[_part.clamp(0, parts.length - 1)];
    if (part == DatePart.dayPeriod) return;
    final width = part == DatePart.year ? 4 : 2;
    _typed = (_typed + digit);
    var n = int.parse(_typed);
    if (part == DatePart.hour && !widget.use24Hour) {
      n = n % 12 + (widget.value.hour >= 12 ? 12 : 0);
    }
    widget.onChanged?.call(_with(part, n));
    // A full part, or one more digit could not fit: on to the next part.
    final max = switch (part) {
      DatePart.day => 3,
      DatePart.month => 1,
      DatePart.hour => widget.use24Hour ? 2 : 1,
      DatePart.minute || DatePart.second => 5,
      _ => 9,
    };
    if (_typed.length >= width || int.parse(_typed) > max) {
      _typed = '';
      if (_part < parts.length - 1) setState(() => _part++);
    }
  }

  KeyEventResult _key(List<DatePart> parts, KeyEvent event) {
    if (!_enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        _typed = '';
        _part = math.max(0, _part - 1);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _typed = '';
        _part = math.min(parts.length - 1, _part + 1);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _stepPart(parts, 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _stepPart(parts, -1);
      return KeyEventResult.handled;
    }
    final char = event.character;
    if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) {
      _type(parts, char);
      return KeyEventResult.handled;
    }
    final part = parts[_part.clamp(0, parts.length - 1)];
    if (part == DatePart.dayPeriod && char != null) {
      final c = char.toLowerCase();
      final wantPm = widget.labels.pm.toLowerCase().startsWith(c);
      final wantAm = widget.labels.am.toLowerCase().startsWith(c);
      if (wantPm != wantAm && wantPm != (widget.value.hour >= 12)) {
        widget.onChanged?.call(_with(DatePart.dayPeriod, 0));
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = InputColors.of(context);
    final active = WindowActiveScope.of(context);
    final parts = _parts(context);
    final focused = _focus.hasFocus;
    final style = inputText(
      widget.enabled ? colors.text : colors.placeholder,
      size: widget.fontSize,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final accent = widget.accent ?? colors.accent;
    final dateSep = '/';
    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        final prev = parts[i - 1], part = parts[i];
        final timeStart = part == DatePart.hour;
        final sep = timeStart
            ? '  '
            : part == DatePart.dayPeriod
            ? ' '
            : prev.index <= DatePart.year.index
            ? dateSep
            : ':';
        children.add(Text(sep, style: style));
      }
      final chosen = focused && _part == i && active;
      children.add(
        GestureDetector(
          onTapDown: _enabled
              ? (_) {
                  _focus.requestFocus();
                  setState(() {
                    _part = i;
                    _typed = '';
                  });
                }
              : null,
          child: Container(
            key: ValueKey('datePart$i'),
            padding: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: chosen ? accent : null,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _text(parts[i]),
              style: chosen
                  ? style.copyWith(color: const Color(0xFFFFFFFF))
                  : style,
            ),
          ),
        ),
      );
    }
    Widget field = Focus(
      focusNode: _focus,
      canRequestFocus: _enabled,
      onKeyEvent: (node, event) => _key(parts, event),
      child: FieldBox(
        focused: focused,
        enabled: widget.enabled,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
    if (widget.fontSize == InputMetrics.fontSize) {
      field = SizedBox(height: InputMetrics.fieldHeight, child: field);
    }
    final part = parts[_part.clamp(0, parts.length - 1)];
    return Semantics(
      label: widget.semanticLabel,
      value: [for (final p in parts) _text(p)].join(' '),
      enabled: _enabled,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          field,
          if (widget.stepper) ...[
            const SizedBox(width: 3),
            SilicaStepper(
              value: _get(part).toDouble(),
              min: -1e9,
              max: 1e9,
              enabled: _enabled,
              onChanged: (v) {
                _stepPart(parts, v > _get(part) ? 1 : -1);
                _focus.requestFocus();
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// The graphical calendar: month header with ◀ ● ▶, weekday initials and the day grid.
class SilicaCalendar extends StatefulWidget {
  const SilicaCalendar({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labels,
    this.firstDayOfWeek = DateTime.monday,
    this.today,
    this.enabled = true,
    this.focusNode,
  });

  final DateTime value;
  final ValueChanged<DateTime>? onChanged;
  final DatePickerLabels labels;

  /// [DateTime.monday] … [DateTime.sunday].
  final int firstDayOfWeek;

  /// Today (marked in the accent); now when null.
  final DateTime? today;
  final bool enabled;
  final FocusNode? focusNode;

  /// Cell side and the selected day's square (provisional sizes).
  static const double cell = 22;
  static const double selection = 20;

  /// The selected day's gray square, light and dark (provisional gray: the inactive list
  /// selection) and its radius (provisional).
  static const Color selectionLight = Color(0xFFDCDCDC);
  static const Color selectionDark = Color(0xFF464646);
  static const double selectionRadius = 4;

  @override
  State<SilicaCalendar> createState() => _SilicaCalendarState();
}

class _SilicaCalendarState extends State<SilicaCalendar> {
  late DateTime _month = DateTime(widget.value.year, widget.value.month);
  bool _focused = false;

  bool get _enabled => widget.enabled && widget.onChanged != null;

  @override
  void didUpdateWidget(SilicaCalendar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _month = DateTime(widget.value.year, widget.value.month);
    }
  }

  void _choose(DateTime day) {
    final v = widget.value;
    widget.onChanged?.call(
      DateTime(day.year, day.month, day.day, v.hour, v.minute, v.second),
    );
  }

  void _moveMonth(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  KeyEventResult _key(KeyEvent event) {
    if (!_enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final v = widget.value;
    final key = event.logicalKey;
    int? days;
    if (key == LogicalKeyboardKey.arrowLeft) days = -1;
    if (key == LogicalKeyboardKey.arrowRight) days = 1;
    if (key == LogicalKeyboardKey.arrowUp) days = -7;
    if (key == LogicalKeyboardKey.arrowDown) days = 7;
    if (days != null) {
      _choose(DateTime(v.year, v.month, v.day + days));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown) {
      final by = key == LogicalKeyboardKey.pageUp ? -1 : 1;
      final target = DateTime(v.year, v.month + by);
      final last = DateTime(target.year, target.month + 1, 0).day;
      _choose(DateTime(target.year, target.month, math.min(v.day, last)));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = InputColors.of(context);
    final active = WindowActiveScope.of(context);
    final dark = SilicaAppearance.isDark(context);
    final accent = active
        ? ControlAccent.of(context)
        : colors.accentFor(active: false);
    final today = widget.today ?? DateTime.now();
    final labels = widget.labels;
    const cell = SilicaCalendar.cell;
    final monthName = labels.monthNames.length == 12
        ? labels.monthNames[_month.month - 1]
        : _month.month.toString();
    final first = DateTime(_month.year, _month.month);
    final lead = (first.weekday - widget.firstDayOfWeek) % 7;
    final start = DateTime(_month.year, _month.month, 1 - lead);
    bool same(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    Widget arrow(String key, String? label, int dir, VoidCallback onTap) =>
        Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            key: ValueKey(key),
            onTap: _enabled ? onTap : null,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CustomPaint(
                painter: _CalendarArrow(direction: dir, color: colors.glyph),
              ),
            ),
          ),
        );
    final header = SizedBox(
      height: 24,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$monthName ${_month.year}',
              style: inputText(
                colors.text,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          arrow(
            'calendarPrevious',
            labels.previousMonth,
            -1,
            () => _moveMonth(-1),
          ),
          arrow('calendarToday', labels.today, 0, () {
            setState(() => _month = DateTime(today.year, today.month));
            _choose(today);
          }),
          arrow('calendarNext', labels.nextMonth, 1, () => _moveMonth(1)),
        ],
      ),
    );
    final weekdays = Row(
      children: [
        for (var i = 0; i < 7; i++)
          SizedBox(
            width: cell,
            child: Text(
              labels.weekdayInitials.length == 7
                  ? labels.weekdayInitials[(widget.firstDayOfWeek + i) % 7]
                  : '',
              textAlign: TextAlign.center,
              style: inputText(colors.secondaryText, size: 11),
            ),
          ),
      ],
    );
    final rows = <Widget>[];
    for (var r = 0; r < 6; r++) {
      rows.add(
        Row(
          children: [
            for (var c = 0; c < 7; c++)
              Builder(
                builder: (context) {
                  final day = DateTime(
                    start.year,
                    start.month,
                    start.day + r * 7 + c,
                  );
                  final inMonth = day.month == _month.month;
                  final selected = same(day, widget.value);
                  final isToday = same(day, today);
                  final color = isToday
                      ? accent
                      : inMonth
                      ? colors.text
                      : colors.placeholder;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: '${day.day}',
                    child: GestureDetector(
                      key: ValueKey('day-${day.year}-${day.month}-${day.day}'),
                      onTap: _enabled ? () => _choose(day) : null,
                      child: SizedBox(
                        width: cell,
                        height: cell,
                        child: Center(
                          child: Container(
                            width: SilicaCalendar.selection,
                            height: SilicaCalendar.selection,
                            alignment: Alignment.center,
                            decoration: selected
                                ? BoxDecoration(
                                    color: dark
                                        ? SilicaCalendar.selectionDark
                                        : SilicaCalendar.selectionLight,
                                    borderRadius: BorderRadius.circular(
                                      SilicaCalendar.selectionRadius,
                                    ),
                                  )
                                : null,

                            child: Text(
                              '${day.day}',
                              style: inputText(color, size: 11).copyWith(
                                fontWeight: isToday ? FontWeight.w600 : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    }
    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: _enabled,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) => _key(event),
      child: FocusRing(
        visible: _focused,
        radius: 6,
        width: InputMetrics.controlRing,
        color: colors.focusRingControl,
        child: Container(
          width: cell * 7 + 18,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.fieldBorder),
          ),
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [header, weekdays, const SizedBox(height: 2), ...rows],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarArrow extends CustomPainter {
  _CalendarArrow({required this.direction, required this.color});
  final int direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()..color = color;
    if (direction == 0) {
      canvas.drawCircle(c, 3, paint);
      return;
    }
    final d = direction.toDouble();
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + 2 * d, c.dy - 4)
        ..lineTo(c.dx - 2.5 * d, c.dy)
        ..lineTo(c.dx + 2 * d, c.dy + 4),
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CalendarArrow old) =>
      old.direction != direction || old.color != color;
}

/// The graphical time picker: a clock face whose hands are dragged. Near the rim the minute
/// hand moves, inside the hour hand; ↑/↓ change the hour, ←/→ the minute.
class SilicaClockFace extends StatefulWidget {
  const SilicaClockFace({
    super.key,
    required this.value,
    required this.onChanged,
    this.diameter = 120,
    this.enabled = true,
    this.focusNode,
    this.semanticLabel,
  });

  final DateTime value;
  final ValueChanged<DateTime>? onChanged;
  final double diameter;
  final bool enabled;
  final FocusNode? focusNode;
  final String? semanticLabel;

  @override
  State<SilicaClockFace> createState() => _SilicaClockFaceState();
}

class _SilicaClockFaceState extends State<SilicaClockFace> {
  bool _focused = false;
  bool? _draggingMinutes;

  bool get _enabled => widget.enabled && widget.onChanged != null;

  DateTime _at({int? hour, int? minute}) {
    final v = widget.value;
    return DateTime(
      v.year,
      v.month,
      v.day,
      hour ?? v.hour,
      minute ?? v.minute,
      v.second,
    );
  }

  void _drag(Offset p, {bool start = false}) {
    final r = widget.diameter / 2;
    final d = p - Offset(r, r);
    if (start) _draggingMinutes = d.distance > r * 0.55;
    var a = math.atan2(d.dx, -d.dy) / (2 * math.pi);
    if (a < 0) a += 1;
    if (_draggingMinutes ?? true) {
      widget.onChanged?.call(_at(minute: (a * 60).round() % 60));
    } else {
      final pm = widget.value.hour >= 12;
      widget.onChanged?.call(_at(hour: (a * 12).round() % 12 + (pm ? 12 : 0)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = InputColors.of(context);
    final active = WindowActiveScope.of(context);
    final v = widget.value;
    String two(int n) => n.toString().padLeft(2, '0');
    return Semantics(
      label: widget.semanticLabel,
      value: '${two(v.hour)}:${two(v.minute)}',
      enabled: _enabled,
      child: Focus(
        focusNode: widget.focusNode,
        canRequestFocus: _enabled,
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (node, event) {
          if (!_enabled ||
              (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowDown) {
            final by = key == LogicalKeyboardKey.arrowUp ? 1 : -1;
            widget.onChanged?.call(_at(hour: (v.hour + by) % 24));
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight) {
            final by = key == LogicalKeyboardKey.arrowRight ? 1 : -1;
            widget.onChanged?.call(_at(minute: (v.minute + by) % 60));
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onPanDown: _enabled
              ? (d) => _drag(d.localPosition, start: true)
              : null,
          onPanUpdate: _enabled ? (d) => _drag(d.localPosition) : null,
          onPanEnd: _enabled ? (_) => _draggingMinutes = null : null,
          child: FocusRing(
            visible: _focused,
            circle: true,
            radius: widget.diameter / 2,
            width: InputMetrics.controlRing,
            color: colors.focusRingControl,
            child: Opacity(
              opacity: widget.enabled ? 1 : 0.5,
              child: CustomPaint(
                size: Size.square(widget.diameter),
                painter: ClockDialPainter(
                  hour: v.hour % 12 + v.minute / 60,
                  minute: v.minute.toDouble(),
                  face: colors.panel,
                  border: colors.fieldBorder,
                  marks: colors.secondaryText,
                  hands: colors.text,
                  accent: colors.accentFor(active: active),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the clock face: dial, hour marks, hour and minute hands.
class ClockDialPainter extends CustomPainter {
  ClockDialPainter({
    required this.hour,
    required this.minute,
    required this.face,
    required this.border,
    required this.marks,
    required this.hands,
    required this.accent,
  });

  final double hour;
  final double minute;
  final Color face;
  final Color border;
  final Color marks;
  final Color hands;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r - 0.5, Paint()..color = face);
    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke,
    );
    Offset dir(double turns) =>
        Offset(math.sin(turns * 2 * math.pi), -math.cos(turns * 2 * math.pi));
    final mark = Paint()
      ..color = marks
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final d = dir(i / 12);
      mark.strokeWidth = i % 3 == 0 ? 1.5 : 1;
      canvas.drawLine(
        c + d * (r - 4),
        c + d * (r - (i % 3 == 0 ? 10 : 7)),
        mark,
      );
    }
    final hand = Paint()
      ..color = hands
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, c + dir(hour / 12) * r * 0.5, hand..strokeWidth = 2.5);
    canvas.drawLine(
      c,
      c + dir(minute / 60) * r * 0.78,
      hand..strokeWidth = 1.5,
    );
    canvas.drawCircle(c, 2.5, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(ClockDialPainter old) =>
      old.hour != hour ||
      old.minute != minute ||
      old.face != face ||
      old.hands != hands ||
      old.accent != accent;
}
