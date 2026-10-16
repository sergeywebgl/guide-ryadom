enum TourAction { nextStop, back, skip, tellMore, surpriseMe, restart }

class Evidence {
  const Evidence({required this.id, required this.title, required this.url});
  final String id;
  final String title;
  final Uri url;
}

class StorySegment {
  StorySegment({
    required this.id,
    required this.text,
    required Set<String> claims,
    required List<String> evidenceIds,
  }) : claims = Set.unmodifiable(claims),
       evidenceIds = List.unmodifiable(evidenceIds);
  final String id;
  final String text;
  final Set<String> claims;
  final List<String> evidenceIds;
}

class TourStop {
  TourStop({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.intro,
    required this.detail,
    required this.surprise,
    required List<Evidence> sources,
  }) : sources = List.unmodifiable(sources);
  final String id;
  final String title;
  final String subtitle;
  final StorySegment intro;
  final StorySegment detail;
  final StorySegment surprise;
  final List<Evidence> sources;
}

/// Prepared fixtures are not consumed until a visible transition selects them.
/// Consumption in M0 means displayed, not necessarily spoken or heard.
class TourEngine {
  TourEngine(List<TourStop> stops) : stops = List.unmodifiable(stops) {
    if (stops.isEmpty) throw ArgumentError('A tour needs at least one stop');
    _show(current.intro);
  }
  final List<TourStop> stops;
  int _index = 0;
  int _revision = 0;
  bool _completed = false;
  late StorySegment _segment;
  final Set<String> _shown = {};
  final Set<String> _consumedClaims = {};
  final Set<String> _skipped = {};
  int get index => _index;
  int get revision => _revision;
  bool get completed => _completed;
  TourStop get current => stops[_index];
  StorySegment get segment => _segment;
  Set<String> get shownSegments => Set.unmodifiable(_shown);
  Set<String> get consumedClaims => Set.unmodifiable(_consumedClaims);
  Set<String> get skippedStops => Set.unmodifiable(_skipped);
  bool get hasDetail => !_shown.contains(current.detail.id) && !_completed;
  bool get hasSurprise => !_shown.contains(current.surprise.id) && !_completed;

  void _show(StorySegment segment) {
    _segment = segment;
    _shown.add(segment.id);
    _consumedClaims.addAll(segment.claims);
  }

  /// The revision identifies the originating UI state: retries cannot advance twice.
  bool dispatch(TourAction action, {required int expectedRevision}) {
    if (expectedRevision != _revision) return false;
    switch (action) {
      case TourAction.restart:
        _index = 0;
        _completed = false;
        _shown.clear();
        _consumedClaims.clear();
        _skipped.clear();
        _show(current.intro);
      case TourAction.back:
        if (_completed) {
          _completed = false;
        } else if (_index > 0) {
          _index--;
        } else {
          return false;
        }
        _show(current.intro);
      case TourAction.nextStop:
      case TourAction.skip:
        if (_completed) return false;
        if (action == TourAction.skip) _skipped.add(current.id);
        if (_index == stops.length - 1) {
          _completed = true;
        } else {
          _index++;
          _show(current.intro);
        }
      case TourAction.tellMore:
        if (!hasDetail) return false;
        _show(current.detail);
      case TourAction.surpriseMe:
        if (!hasSurprise) return false;
        _show(current.surprise);
    }
    _revision++;
    return true;
  }
}
