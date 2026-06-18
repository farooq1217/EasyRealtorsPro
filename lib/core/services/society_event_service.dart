import 'dart:async';

enum SocietyEventType { 
  created, 
  updated, 
  deleted 
}

class SocietyEvent {
  final SocietyEventType type;
  final Map<String, String> data;
  
  SocietyEvent(this.type, this.data);
}

class SocietyEventService {
  static final SocietyEventService _instance = SocietyEventService._internal();
  factory SocietyEventService() => _instance;
  SocietyEventService._internal();

  final _controller = StreamController<SocietyEvent>.broadcast();

  Stream<SocietyEvent> get onSocietyChanged => _controller.stream;

  void notifySocietyCreated(Map<String, String> society) {
    _controller.add(SocietyEvent(SocietyEventType.created, society));
  }

  void notifySocietyUpdated(Map<String, String> society) {
    _controller.add(SocietyEvent(SocietyEventType.updated, society));
  }

  void notifySocietyDeleted(String societyId) {
    _controller.add(SocietyEvent(SocietyEventType.deleted, {'id': societyId}));
  }

  void dispose() {
    _controller.close();
  }
}