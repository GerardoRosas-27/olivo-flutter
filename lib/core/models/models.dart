import 'dart:convert';

typedef RsvpStatus = String; // unknown | yes | no

class ScheduleItem {
  const ScheduleItem({
    required this.time,
    required this.title,
    required this.detail,
  });

  final String time;
  final String title;
  final String detail;

  Map<String, dynamic> toJson() => {
        'time': time,
        'title': title,
        'detail': detail,
      };

  factory ScheduleItem.fromJson(Map<String, dynamic> j) => ScheduleItem(
        time: j['time'] as String? ?? '',
        title: j['title'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
      );
}

class Wedding {
  const Wedding({
    required this.id,
    required this.userId,
    required this.partnerOne,
    required this.partnerTwo,
    this.weddingDate,
    required this.weddingTime,
    required this.venueName,
    required this.venueAddress,
    required this.venueMapsUrl,
    required this.dressCode,
    required this.story,
    required this.welcomeNote,
    required this.schedule,
    required this.whatsappTemplate,
    this.rsvpDeadline,
  });

  final String id;
  final String userId;
  final String partnerOne;
  final String partnerTwo;
  final String? weddingDate;
  final String weddingTime;
  final String venueName;
  final String venueAddress;
  final String venueMapsUrl;
  final String dressCode;
  final String story;
  final String welcomeNote;
  final List<ScheduleItem> schedule;
  final String whatsappTemplate;
  final String? rsvpDeadline;

  Wedding copyWith({
    String? partnerOne,
    String? partnerTwo,
    String? weddingDate,
    String? weddingTime,
    String? venueName,
    String? venueAddress,
    String? venueMapsUrl,
    String? dressCode,
    String? story,
    String? welcomeNote,
    List<ScheduleItem>? schedule,
    String? whatsappTemplate,
    String? rsvpDeadline,
  }) {
    return Wedding(
      id: id,
      userId: userId,
      partnerOne: partnerOne ?? this.partnerOne,
      partnerTwo: partnerTwo ?? this.partnerTwo,
      weddingDate: weddingDate ?? this.weddingDate,
      weddingTime: weddingTime ?? this.weddingTime,
      venueName: venueName ?? this.venueName,
      venueAddress: venueAddress ?? this.venueAddress,
      venueMapsUrl: venueMapsUrl ?? this.venueMapsUrl,
      dressCode: dressCode ?? this.dressCode,
      story: story ?? this.story,
      welcomeNote: welcomeNote ?? this.welcomeNote,
      schedule: schedule ?? this.schedule,
      whatsappTemplate: whatsappTemplate ?? this.whatsappTemplate,
      rsvpDeadline: rsvpDeadline ?? this.rsvpDeadline,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'partnerOne': partnerOne,
        'partnerTwo': partnerTwo,
        'weddingDate': weddingDate,
        'weddingTime': weddingTime,
        'venueName': venueName,
        'venueAddress': venueAddress,
        'venueMapsUrl': venueMapsUrl,
        'dressCode': dressCode,
        'story': story,
        'welcomeNote': welcomeNote,
        'schedule': schedule.map((e) => e.toJson()).toList(),
        'whatsappTemplate': whatsappTemplate,
        'rsvpDeadline': rsvpDeadline,
      };

  factory Wedding.fromJson(Map<String, dynamic> j) {
    final sched = j['schedule'];
    List<ScheduleItem> schedule = [];
    if (sched is List) {
      schedule = sched
          .map((e) => ScheduleItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else if (sched is String && sched.isNotEmpty) {
      try {
        final parsed = jsonDecode(sched) as List;
        schedule = parsed
            .map((e) => ScheduleItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }
    return Wedding(
      id: j['id'] as String,
      userId: j['userId'] as String? ?? j['user_id'] as String? ?? '',
      partnerOne: j['partnerOne'] as String? ?? j['partner_one'] as String? ?? '',
      partnerTwo: j['partnerTwo'] as String? ?? j['partner_two'] as String? ?? '',
      weddingDate: j['weddingDate'] as String? ?? j['wedding_date'] as String?,
      weddingTime: j['weddingTime'] as String? ?? j['wedding_time'] as String? ?? '',
      venueName: j['venueName'] as String? ?? j['venue_name'] as String? ?? '',
      venueAddress: j['venueAddress'] as String? ?? j['venue_address'] as String? ?? '',
      venueMapsUrl: j['venueMapsUrl'] as String? ?? j['venue_maps_url'] as String? ?? '',
      dressCode: j['dressCode'] as String? ?? j['dress_code'] as String? ?? '',
      story: j['story'] as String? ?? '',
      welcomeNote: j['welcomeNote'] as String? ?? j['welcome_note'] as String? ?? '',
      schedule: schedule,
      whatsappTemplate:
          j['whatsappTemplate'] as String? ?? j['whatsapp_template'] as String? ?? '',
      rsvpDeadline: j['rsvpDeadline'] as String? ?? j['rsvp_deadline'] as String?,
    );
  }
}

class Guest {
  const Guest({
    required this.id,
    required this.weddingId,
    required this.name,
    required this.phone,
    required this.partySize,
    required this.groupName,
    required this.notes,
    required this.token,
    required this.rsvp,
    this.rsvpAt,
    this.sentAt,
    this.firstViewedAt,
    this.boundDeviceId,
    this.checkedInAt,
    this.cloneFlaggedAt,
    this.discardedAt,
    required this.scanCount,
    required this.checkedInCount,
    required this.createdAt,
  });

  final String id;
  final String weddingId;
  final String name;
  final String phone;
  final int partySize;
  final String groupName;
  final String notes;
  final String token;
  final String rsvp;
  final String? rsvpAt;
  final String? sentAt;
  final String? firstViewedAt;
  final String? boundDeviceId;
  final String? checkedInAt;
  final String? cloneFlaggedAt;
  final String? discardedAt;
  final int scanCount;
  /// Successful door check-ins against [partySize] cupo.
  final int checkedInCount;
  final String createdAt;

  bool get isDiscarded => discardedAt != null;
  bool get isCloned => cloneFlaggedAt != null;
  bool get isCheckedIn => checkedInAt != null || checkedInCount > 0;
  bool get isQuotaFull => checkedInCount >= partySize;
  bool get hasPartialCheckIn =>
      checkedInCount > 0 && checkedInCount < partySize;

  Guest copyWith({
    String? name,
    String? phone,
    int? partySize,
    String? groupName,
    String? notes,
    String? token,
    String? rsvp,
    String? rsvpAt,
    String? sentAt,
    String? firstViewedAt,
    String? boundDeviceId,
    String? checkedInAt,
    String? cloneFlaggedAt,
    String? discardedAt,
    int? scanCount,
    int? checkedInCount,
  }) {
    return Guest(
      id: id,
      weddingId: weddingId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      partySize: partySize ?? this.partySize,
      groupName: groupName ?? this.groupName,
      notes: notes ?? this.notes,
      token: token ?? this.token,
      rsvp: rsvp ?? this.rsvp,
      rsvpAt: rsvpAt ?? this.rsvpAt,
      sentAt: sentAt ?? this.sentAt,
      firstViewedAt: firstViewedAt ?? this.firstViewedAt,
      boundDeviceId: boundDeviceId ?? this.boundDeviceId,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      cloneFlaggedAt: cloneFlaggedAt ?? this.cloneFlaggedAt,
      discardedAt: discardedAt ?? this.discardedAt,
      scanCount: scanCount ?? this.scanCount,
      checkedInCount: checkedInCount ?? this.checkedInCount,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'weddingId': weddingId,
        'name': name,
        'phone': phone,
        'partySize': partySize,
        'groupName': groupName,
        'notes': notes,
        'token': token,
        'rsvp': rsvp,
        'rsvpAt': rsvpAt,
        'sentAt': sentAt,
        'firstViewedAt': firstViewedAt,
        'boundDeviceId': boundDeviceId,
        'checkedInAt': checkedInAt,
        'cloneFlaggedAt': cloneFlaggedAt,
        'discardedAt': discardedAt,
        'scanCount': scanCount,
        'checkedInCount': checkedInCount,
        'createdAt': createdAt,
      };

  factory Guest.fromJson(Map<String, dynamic> j) {
    final party = (j['partySize'] as num?)?.toInt() ??
        (j['party_size'] as num?)?.toInt() ??
        1;
    final checkedInAt =
        j['checkedInAt'] as String? ?? j['checked_in_at'] as String?;
    var checkedInCount = (j['checkedInCount'] as num?)?.toInt() ??
        (j['checked_in_count'] as num?)?.toInt();
    // Legacy: if checked in but no count stored, treat as 1 toward cupo.
    checkedInCount ??= (checkedInAt != null ? 1 : 0);
    return Guest(
      id: j['id'] as String,
      weddingId: j['weddingId'] as String? ?? j['wedding_id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      partySize: party,
      groupName: j['groupName'] as String? ?? j['group_name'] as String? ?? '',
      notes: j['notes'] as String? ?? '',
      token: j['token'] as String? ?? '',
      rsvp: j['rsvp'] as String? ?? 'unknown',
      rsvpAt: j['rsvpAt'] as String? ?? j['rsvp_at'] as String?,
      sentAt: j['sentAt'] as String? ?? j['sent_at'] as String?,
      firstViewedAt:
          j['firstViewedAt'] as String? ?? j['first_viewed_at'] as String?,
      boundDeviceId:
          j['boundDeviceId'] as String? ?? j['bound_device_id'] as String?,
      checkedInAt: checkedInAt,
      cloneFlaggedAt:
          j['cloneFlaggedAt'] as String? ?? j['clone_flagged_at'] as String?,
      discardedAt:
          j['discardedAt'] as String? ?? j['discarded_at'] as String?,
      scanCount: (j['scanCount'] as num?)?.toInt() ??
          (j['scan_count'] as num?)?.toInt() ??
          0,
      checkedInCount: checkedInCount,
      createdAt: j['createdAt'] as String? ?? j['created_at'] as String? ?? '',
    );
  }
}

class ScanEvent {
  const ScanEvent({
    required this.id,
    required this.guestId,
    required this.guestName,
    required this.kind,
    required this.deviceId,
    required this.outcome,
    required this.createdAt,
  });

  final String id;
  final String guestId;
  final String guestName;
  final String kind;
  final String deviceId;
  final String outcome;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'guestId': guestId,
        'guestName': guestName,
        'kind': kind,
        'deviceId': deviceId,
        'outcome': outcome,
        'createdAt': createdAt,
      };

  factory ScanEvent.fromJson(Map<String, dynamic> j) => ScanEvent(
        id: j['id'] as String,
        guestId: j['guestId'] as String? ?? j['guest_id'] as String? ?? '',
        guestName: j['guestName'] as String? ?? j['guest_name'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
        deviceId: j['deviceId'] as String? ?? j['device_id'] as String? ?? '',
        outcome: j['outcome'] as String? ?? '',
        createdAt: j['createdAt'] as String? ?? j['created_at'] as String? ?? '',
      );
}

class AdminStats {
  const AdminStats({
    required this.guests,
    required this.sent,
    required this.viewed,
    required this.confirmed,
    required this.declined,
    required this.checkedIn,
    required this.clones,
    required this.expected,
  });

  final int guests;
  final int sent;
  final int viewed;
  final int confirmed;
  final int declined;
  final int checkedIn;
  final int clones;
  final int expected;
}

class DoorScanResult {
  const DoorScanResult({required this.outcome, this.guest});

  /// checked_in | already_in | full | cloned | discarded | missing
  final String outcome;
  final Guest? guest;
}

class SessionUser {
  const SessionUser({required this.email, required this.userId});

  final String email;
  final String userId;

  Map<String, dynamic> toJson() => {'email': email, 'userId': userId};

  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
        email: j['email'] as String,
        userId: j['userId'] as String,
      );
}

const defaultTemplate = '''Hola {nombre},

Con mucho cariño te invitamos a nuestra boda.

{novios}
{fecha} · {hora}
{lugar}
{direccion}

Tu invitación digital (enlace + QR en la página):
{enlace}

Cupo: {cupo} persona(s)

Esperamos verte.''';

const defaultSchedule = [
  ScheduleItem(time: '16:00', title: 'Ceremonia', detail: 'Jardín principal'),
  ScheduleItem(time: '17:30', title: 'Brindis', detail: 'Terraza'),
  ScheduleItem(time: '19:00', title: 'Cena', detail: 'Salón de naranjos'),
  ScheduleItem(time: '21:00', title: 'Baile', detail: 'Hasta que el cuerpo aguante'),
];
