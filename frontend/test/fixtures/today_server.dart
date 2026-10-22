import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../support/archive_all_preview.dart' as base;
import '../support/original_link_preview.dart';

/// Fixed HTTP contract double, not a recommendation algorithm implementation.
class TodayServer extends OriginalLinkPreviewServer {
  TodayServer() { resetToday(); }
  String mode = 'normal';
  Completer<void>? pending;
  final calls = <Map<String, dynamic>>[];
  List<int> ids = [606, 604, 602, 605, 603];
  List<int> ranks = [1, 2, 3, 4, 5];
  final missing = <int>{};
  String date = '2026-10-21';
  void resetToday([String value = 'normal']) {
    records..clear()..addAll(base.archiveAllRecords());
    reset('link');
    records[5] = {...records[5], 'title':'오늘 다시 볼 저장 기록',
      'categories':[base.archiveAllCategoryMaps.first],
      'original_url':originalPreviewUrl};
    mode = value; calls.clear(); metrics.clear(); missing.clear();
    ids = [606,604,602,605,603]; ranks=[1,2,3,4,5]; pending=null;
  }
  Map<String, dynamic> response() => {
    'stage':mode=='stage0'?0:1, 'recommendation_date':date,
    'batch_id':mode=='stage0'?null:71,
    'generated_at':mode=='stage0'?null:'2026-10-21T10:00:00Z',
    'items':mode=='stage0'||mode=='empty'?<Object>[]:[
      for(var i=0;i<ids.length;i++) {
        'recommendation_item_id':700+ids[i], 'rank':ranks[i],
        'content':records.firstWhere((r)=>r['id']==ids[i]),
      }
    ],
  };
  late final todayClient = MockClient((request) async {
    final path=request.url.path;
    calls.add({'method':request.method,'path':path,'query':request.url.queryParameters,
      if(request.body.isNotEmpty) 'body':jsonDecode(request.body)});
    if(path=='/api/v1/recommendations/today') {
      final snapshot=response(); await pending?.future;
      return mode=='error'?this.json({'detail':'controlled failure'},503):this.json(snapshot);
    }
    if(path=='/api/v1/feed' && request.url.queryParameters['category_id']==null) {
      return this.json({'items':records.take(4).toList(),'next_cursor':null});
    }
    final match=RegExp(r'^/api/v1/contents/(\d+)$').firstMatch(path);
    if(match!=null && missing.contains(int.parse(match[1]!))) {
      return this.json({'detail':'not found'},404);
    }
    final copy=http.Request(request.method,request.url)
      ..headers.addAll(request.headers)..bodyBytes=request.bodyBytes;
    return previewClient.send(copy).then(http.Response.fromStream);
  });
}
