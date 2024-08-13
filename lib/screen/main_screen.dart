import 'dart:async';
import 'package:amplify_api/amplify_api.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mini_project_five/models/ModelProvider.dart';
import 'package:mini_project_five/amplifyconfiguration.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api_dart/amplify_api_dart.dart';
import 'package:uuid/uuid.dart';

class AfternoonService extends StatefulWidget {
  final Function(int) updateSelectedBox;

  AfternoonService({required this.updateSelectedBox});

  @override
  _AfternoonServiceState createState() => _AfternoonServiceState();
}

class _AfternoonServiceState extends State<AfternoonService> {
  DateTime currentTime = DateTime.now();
  String? BookingID;
  String selectedBusStop = '';


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _configureAmplify();
  }

  void _configureAmplify() async {
    final provider = ModelProvider();
    final amplifyApi = AmplifyAPI(options: APIPluginOptions(modelProvider: provider));
    final dataStorePlugin = AmplifyDataStore(modelProvider: provider);

    Amplify.addPlugin(dataStorePlugin);
    Amplify.addPlugin(amplifyApi);
    Amplify.configure(amplifyconfig);

    print('Amplify configured');
  }

  Future<void> create(String _MRTStation, int _TripNo, String _BusStop) async {
    try {
      final model = BOOKINGDETAILS5(
        id: Uuid().v4(),
        MRTStation: _MRTStation,
        TripNo: _TripNo,
        BusStop: _BusStop,
      );

      final request = ModelMutations.create(model);
      final response = await Amplify.API.mutate(request: request).response;

      final createdBOOKINGDETAILS5 = response.data;
      if (createdBOOKINGDETAILS5 == null) {
        safePrint('errors: ${response.errors}');
        return;
      }

      String id  = createdBOOKINGDETAILS5.id;
      setState(() {
        BookingID = id;
      });
      safePrint('Mutation result: $BookingID');// Return the ID of the created object
    } on ApiException catch (e) {
      safePrint('Mutation failed: $e');
    }

    _MRTStation=='KAP'? countKAP(_TripNo, _BusStop): countCLE(_TripNo, _BusStop);

  }
  Future<BOOKINGDETAILS5?> readByID() async {
    final request = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.ID.eq(BookingID),
    );
    final response = await Amplify.API.query(request: request).response;
    final data = response.data?.items.firstOrNull;
    return data;
  }

  Future<int?> countBooking(String MRT, int TripNo) async{
    int? count;
    try {
      final request = ModelQueries.list(
        BOOKINGDETAILS5.classType,
        where: BOOKINGDETAILS5.MRTSTATION.eq(MRT).and(
            BOOKINGDETAILS5.TRIPNO.eq(TripNo)),
      );
      final response = await Amplify.API
          .query(request: request)
          .response;
      final data = response.data?.items;

      if (data != null) {
        count = data.length;
        print('$count');
      }
      else
        count = 0;
    }
    catch (e) {
      print('$e');
    }
    return count;
    //await Future.delayed(Duration(seconds:10));

  }

  Future<void> delete() async {
    final BOOKINGDETAILS5? bookingToDelete = await readByID();
    if (bookingToDelete != null) {
      final request = ModelMutations.delete(bookingToDelete);
      final response = await Amplify.API.mutate(request: request).response;
      if(bookingToDelete.MRTStation == 'KAP')
        countKAP(bookingToDelete.TripNo, bookingToDelete.BusStop);
      else
        countCLE(bookingToDelete.TripNo, bookingToDelete.BusStop);
    } else {
      print('No booking found with ID: $BookingID');
    }
  }

  Future<void> countCLE(int _TripNo, String _BusStop) async {
    int? count;
    //read if there is row
    final request1 = ModelQueries.list(
      CLE.classType,
      where: CLE.TRIPNO.eq(_TripNo).and(CLE.BUSSTOP.eq(_BusStop)),
    );
    final response1 = await Amplify.API
        .query(request: request1)
        .response;
    final data1 = response1.data?.items.firstOrNull;
    print('Row found');

    //if data1 != null delete that row
    if (data1 != null) {
      final request2 = ModelMutations.delete(data1);
      final response2 = await Amplify.API
          .mutate(request: request2)
          .response;
    }
    //count booking
    final request3 = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.MRTSTATION.eq('CLE').and(
          BOOKINGDETAILS5.TRIPNO.eq(_TripNo)).and(
          BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
    );
    final response3 = await Amplify.API
        .query(request: request3)
        .response;
    final data2 = response3.data?.items;
    if (data2 != null) {
      count = data2.length;
      print('$count');
    }
    else{
      count = 0;
    }
    //create the row
    final model = CLE(
      BusStop: _BusStop,
      TripNo: _TripNo,
      Count: count,
    );
    final request4 = ModelMutations.create(model);
    final response4 = await Amplify.API.mutate(request: request4).response;

    final createdCLE = response4.data;
  }

  Future<void> countKAP(int _TripNo, String _BusStop) async {
    int? count;
    //read if there is row
    final request1 = ModelQueries.list(
      KAP.classType,
      where: KAP.TRIPNO.eq(_TripNo).and(KAP.BUSSTOP.eq(_BusStop)),
    );
    final response1 = await Amplify.API
        .query(request: request1)
        .response;
    final data1 = response1.data?.items.firstOrNull;
    print('Row found');

    //if data1 != null delete that row
    if (data1 != null) {
      final request2 = ModelMutations.delete(data1);
      final response2 = await Amplify.API
          .mutate(request: request2)
          .response;
    }
    //count booking
    final request3 = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.MRTSTATION.eq('KAP').and(
          BOOKINGDETAILS5.TRIPNO.eq(_TripNo)).and(
          BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
    );
    final response3 = await Amplify.API
        .query(request: request3)
        .response;
    final data2 = response3.data?.items;
    if (data2 != null) {
      count = data2.length;
      print('$count');
    }
    else{
      count = 0;
    }
    //create the row
    final model = KAP(
      BusStop: _BusStop,
      TripNo: _TripNo,
      Count: count,
    );
    final request4 = ModelMutations.create(model);
    final response4 = await Amplify.API.mutate(request: request4).response;

    final createdKAP = response4.data;
  }

  String formatTime(DateTime time) {
    String hour = time.hour.toString().padLeft(2, '0');
    String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Testing")
      ],
    );
  }
}
