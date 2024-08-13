import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mini_project_five/pages/loading.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:mini_project_five/models/ModelProvider.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api_dart/amplify_api_dart.dart';
import 'package:uuid/uuid.dart';
import 'package:mini_project_five/amplifyconfiguration.dart';
import 'package:mini_project_five/pages/busdata.dart';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart';
import 'dart:convert';

class Map_Page extends StatefulWidget {
  const Map_Page({super.key});

  @override
  State<Map_Page> createState() => _Map_PageState();
}

class _Map_PageState extends State<Map_Page> {
  final ScrollController controller = ScrollController();
  final BusInfo _BusInfo = BusInfo();
  String? selectedMRT;
  int? selectedTripNo;
  String? selectedBusStop;
  int BusStop_Index = 8;
  final int CLE_TripNo = 4;
  final int KAP_TripNo = 13;
  //int? bookingCount;
  String? BookingID;
  List<String> BusStops = [];
  int? trackBooking;
  late Timer _timer;
  int? totalBooking;
  bool loading_totalcount = true;
  bool loading_count = true;
  late double screen_width;
  late double screen_height;
  int full_capacity = 5;
  List<DateTime> KAP_DT = [];
  List<DateTime> CLE_DT = [];


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    BusStops = _BusInfo.BusStop;
    BusStops = BusStops.sublist(2); //sublist used to start from index 2
    selectedBusStop = BusStops[BusStop_Index];
    _configureAmplify();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateTotalBooking();
      _updateBooking();
    });
  }

  @override
  void dispose(){
    _timer.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    screen_height = MediaQuery.of(context).size.height;
    screen_width = MediaQuery.of(context).size.width;
  }

  void showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Alert'),
          content: Text('Please select MRT, BusStop, and TripNo.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void fullAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Alert'),
          content: Text('Booking Full'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void showVoidDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Alert'),
          content: Text('No Booking to delete'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _updateBooking() async{
    if (selectedTripNo != null && selectedBusStop != null && selectedMRT != null) {
      if (selectedMRT == 'CLE') {
        trackBooking = await getcountCLE(selectedTripNo!, selectedBusStop!) ?? 0;
      } else {
        trackBooking = await getcountKAP(selectedTripNo!, selectedBusStop!) ?? 0;
      }
      setState(() {
        trackBooking = trackBooking;
        loading_count = false;
      });
    }
  }

  void _updateTotalBooking() async{
    if (selectedMRT != null && selectedTripNo != null) {
           totalBooking = await countBooking(selectedMRT!, selectedTripNo!);
    }
    setState(() {
      totalBooking = totalBooking;
      loading_totalcount = false;
    });
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

      String id = createdBOOKINGDETAILS5.id;
      setState(() {
        BookingID = id;
      });
      safePrint('Mutation result: $BookingID'); // Return the ID of the created object

      // Ensure count update happens only after the booking creation is confirmed
      if (_MRTStation == 'KAP') {
        await countKAP(_TripNo, _BusStop);
      } else {
        await countCLE(_TripNo, _BusStop);
      }
    } on ApiException catch (e) {
      safePrint('Mutation failed: $e');
    }
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

  Future<BOOKINGDETAILS5?> Search_Instance(String MRT, int TripNo, String BusStop) async{
  final request = ModelQueries.list(
    BOOKINGDETAILS5.classType,
    where: (BOOKINGDETAILS5.MRTSTATION.eq(MRT).and(
      BOOKINGDETAILS5.TRIPNO.eq(TripNo).and(
        BOOKINGDETAILS5.BUSSTOP.eq(BusStop)
      ))));
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
  }

  Future<void> Minus(String _MRT, int _TripNo, String _BusStop) async{
  final BOOKINGDETAILS5? bookingToDelete = await Search_Instance(_MRT, _TripNo, _BusStop);
  if (bookingToDelete != null) {
    final request = ModelMutations.delete(bookingToDelete);
    final response = await Amplify.API.mutate(request: request).response;
    if(bookingToDelete.MRTStation == 'KAP')
      countKAP(bookingToDelete.TripNo, bookingToDelete.BusStop);
    else
      countCLE(bookingToDelete.TripNo, bookingToDelete.BusStop);
  } else {
    print('No booking deleted');
  }
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

  Future<int?> getcountCLE(int _TripNo, String _BusStop) async {
    int? count;
    // Read if there is a row
    final request1 = ModelQueries.list(
      CLE.classType,
      where: CLE.TRIPNO.eq(_TripNo).and(CLE.BUSSTOP.eq(_BusStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    print('Row found');
    // If data1 != null, delete that row
    if (data1 != null) {
      final request2 = ModelMutations.delete(data1);
      final response2 = await Amplify.API.mutate(request: request2).response;
    }
    // Count booking
    final request3 = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.MRTSTATION.eq('CLE').and(
          BOOKINGDETAILS5.TRIPNO.eq(_TripNo)).and(
          BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    if (data2 != null) {
      count = data2.length;
      print('$count');
    } else {
      count = 0;
    }
    // If count is greater than 0, create the row
    if (count > 0) {
      final model = CLE(
        BusStop: _BusStop,
        TripNo: _TripNo,
        Count: count,
      );
    }
    return count;
  }

  Future<int?> countCLE(int _TripNo, String _BusStop) async {
    int? count;
    // Read if there is a row
    final request1 = ModelQueries.list(
      CLE.classType,
      where: CLE.TRIPNO.eq(_TripNo).and(CLE.BUSSTOP.eq(_BusStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    print('Row found');

    // If data1 != null, delete that row
    if (data1 != null) {
      final request2 = ModelMutations.delete(data1);
      final response2 = await Amplify.API.mutate(request: request2).response;
    }

    // Count booking
    final request3 = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.MRTSTATION.eq('CLE').and(
          BOOKINGDETAILS5.TRIPNO.eq(_TripNo)).and(
          BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    if (data2 != null) {
      count = data2.length;
      print('$count');
    } else {
      count = 0;
    }

    // If count is greater than 0, create the row
    if (count > 0) {
      final model = CLE(
        BusStop: _BusStop,
        TripNo: _TripNo,
        Count: count,
      );
      final request4 = ModelMutations.create(model);
      final response4 = await Amplify.API.mutate(request: request4).response;
      final createdCLE = response4.data;
    }

    return count;
  }


  Future<int?> getcountKAP(int _TripNo, String _BusStop) async {
    int? count;
    // Read if there is a row
    final request1 = ModelQueries.list(
      KAP.classType,
      where: KAP.TRIPNO.eq(_TripNo).and(KAP.BUSSTOP.eq(_BusStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    print('Row found');
    // If data1 != null, delete that row
    if (data1 != null) {
      final request2 = ModelMutations.delete(data1);
      final response2 = await Amplify.API.mutate(request: request2).response;
    }
    // Count booking
    final request3 = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.MRTSTATION.eq('KAP').and(
          BOOKINGDETAILS5.TRIPNO.eq(_TripNo)).and(
          BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    if (data2 != null) {
      count = data2.length;
      print('$count');
    } else {
      count = 0;
    }
    // If count is greater than 0, create the row
    if (count > 0) {
      final model = KAP(
        BusStop: _BusStop,
        TripNo: _TripNo,
        Count: count,
      );
    }
    print("Returning KAP count");
    print("$count");
    return count;
  }

  Future<int?> countKAP(int _TripNo, String _BusStop) async {
    int? count;
    // Read if there is a row
    final request1 = ModelQueries.list(
      KAP.classType,
      where: KAP.TRIPNO.eq(_TripNo).and(KAP.BUSSTOP.eq(_BusStop)),
    );
    final response1 = await Amplify.API.query(request: request1).response;
    final data1 = response1.data?.items.firstOrNull;
    print('Row found');

    // If data1 != null, delete that row
    if (data1 != null) {
      final request2 = ModelMutations.delete(data1);
      final response2 = await Amplify.API.mutate(request: request2).response;
    }

    // Count booking
    final request3 = ModelQueries.list(
      BOOKINGDETAILS5.classType,
      where: BOOKINGDETAILS5.MRTSTATION.eq('KAP').and(
          BOOKINGDETAILS5.TRIPNO.eq(_TripNo)).and(
          BOOKINGDETAILS5.BUSSTOP.eq(_BusStop)),
    );
    final response3 = await Amplify.API.query(request: request3).response;
    final data2 = response3.data?.items;
    if (data2 != null) {
      count = data2.length;
      print('$count');
    } else {
      count = 0;
    }
    // If count is greater than 0, create the row
    if (count > 0) {
      final model = KAP(
        BusStop: _BusStop,
        TripNo: _TripNo,
        Count: count,
      );
      final request4 = ModelMutations.create(model);
      final response4 = await Amplify.API.mutate(request: request4).response;
      final createdKAP = response4.data;
    }
    print("Returning KAP count");
    print("$count");
    return count;
  }


  List<DropdownMenuItem<int>> _buildTripNoItems(int tripNo) {
    return List<DropdownMenuItem<int>>.generate(
      tripNo,
          (int index) => DropdownMenuItem<int>(
        value: index + 1,
        child: Text('${index + 1}'),
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildBusStopItems() {
    return BusStops.map((String busStop) {
      return DropdownMenuItem<String>(
        value: busStop,
        child: Text(busStop),
      );
    }).toList();
  }

  //


  @override
  Widget build(BuildContext context) {
    print("TrackBooking & TotalBooking");
    print("$trackBooking");
    print("$totalBooking");
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(1.333858545682901, 103.77615110817143),
              initialZoom: 18,
              interactionOptions: const InteractionOptions(flags: ~InteractiveFlag.doubleTapZoom),
            ),
            nonRotatedChildren: [
              SimpleAttributionWidget(source: Text('OpenStreetMap contributors'))
            ],
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.fleaflet.flutter_map.example',
              ),
            ],
          ),
          SlidingUpPanel(
            panelBuilder: (controller) {
              return Container(
                color: Colors.lightBlue[100],
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Moovita Connect',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Select MRT Station',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * 0.04,
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w600,
                                ),),
                              SizedBox(height: 5.0),
                              SizedBox(
                                width: 150, // Fixed width for consistency
                                child: DropdownButton<String>(
                                  value: selectedMRT,
                                  items: ['CLE', 'KAP'].map<DropdownMenuItem<String>>((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedMRT = newValue;
                                      selectedTripNo = null;  // Reset selected trip no when MRT station changes
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: MediaQuery.of(context).size.width * 0.07),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Select Trip No',
                                  style: TextStyle(
                                    fontSize: MediaQuery.of(context).size.width * 0.04,
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.w600,
                                  ),),
                                SizedBox(height: 5.0),
                                SizedBox(
                                  width: 150, // Fixed width for consistency
                                  child: DropdownButton<int>(
                                    value: selectedTripNo,
                                    items: selectedMRT == 'CLE'
                                        ? _buildTripNoItems(_BusInfo.CLEDepartureTime.length)
                                        : selectedMRT == 'KAP'
                                        ? _buildTripNoItems(_BusInfo.KAPDepartureTime.length)
                                        : [],
                                    onChanged: (int? newValue) {
                                      setState(() {
                                        selectedTripNo = newValue;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                          Text('Select Bus Stop',
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width * 0.04,
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w600,
                            ),),
                          SizedBox(width: MediaQuery.of(context).size.width * 0.2),
                          IconButton(
                              onPressed: (){
                                setState(() {
                                  BusStop_Index = (BusStop_Index - 1) < 0 ? BusStops.length - 1 : BusStop_Index - 1;
                                  selectedBusStop = BusStops[BusStop_Index];
                                });
                              },
                              icon: Icon(Icons.arrow_back_ios)),
                          DropdownButton<String>(
                            value: selectedBusStop, // Define and update selectedBusStop state variable
                            items: _buildBusStopItems(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedBusStop = newValue;
                                BusStop_Index = BusStops.indexOf(newValue!);
                              });
                            },
                          ),
                          IconButton(
                              onPressed: (){
                                setState(() {
                                  BusStop_Index = (BusStop_Index + 1) % BusStops.length;
                                  selectedBusStop = BusStops[BusStop_Index];
                                });
                              },
                              icon: Icon(Icons.arrow_forward_ios))
                        ],
                      ),
                      SizedBox(height: 20.0),
                      Row(
                        children: [
                          SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                          Text("Total booking for this trip: ",
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w900,
                              fontSize: MediaQuery.of(context).size.width * 0.05
                            ),),
                          SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                          Container(
                            color: Colors.white,
                            width: MediaQuery.of(context).size.width * 0.2,
                              child: Row(
                                children: [
                                  SizedBox(width: 10),
                                  Text("${totalBooking!= null ? totalBooking : 0}",
                                    style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18
                                    ),),
                                ],
                              )
                          )
                        ],
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          SizedBox(width: MediaQuery.of(context).size.width * 0.05),
                          Text("Booking for this stop: ",
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w900,
                                fontSize: MediaQuery.of(context).size.width * 0.05
                            ),),
                          SizedBox(width: MediaQuery.of(context).size.width * 0.095),
                          Container(
                              color: Colors.white,
                              width: MediaQuery.of(context).size.width * 0.2,
                              child: Row(
                                children: [
                                  SizedBox(width: 10),
                                  Text("${trackBooking != null ? trackBooking : 0}",
                                    style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18
                                    ),),
                                ],
                              ))
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          SizedBox(width: MediaQuery.of(context).size.width*0.35),
                          IconButton(
                            onPressed: (){
                              if (selectedMRT != null && selectedTripNo != null && selectedBusStop != null){
                                Minus(selectedMRT!, selectedTripNo!, selectedBusStop!);
                              }
                              else if (selectedMRT == null || selectedTripNo == null || selectedBusStop == null) {
                                showAlertDialog(context);
                              }
                              if (trackBooking == 0){
                              showVoidDialog(context);
                              }
                            },
                              icon: Icon(Icons.remove_circle,
                              color: Colors.red,
                              size: 35),),
                          SizedBox(width: MediaQuery.of(context).size.width*0.05),
                          IconButton(
                            onPressed: () {
                              if (selectedMRT != null && selectedTripNo != null && selectedBusStop != null && totalBooking! < full_capacity) {
                                create(selectedMRT!, selectedTripNo!, selectedBusStop!);
                              } else if (selectedMRT == null || selectedTripNo == null || selectedBusStop == null) {
                                showAlertDialog(context);
                              }
                              else if (totalBooking! >= full_capacity){
                              fullAlertDialog(context);
                              }
                            },
                            icon: Icon(
                              Icons.add_circle,
                              color: Colors.green,
                              size: 35,
                            ),
                          ),

                        ],
                      ),
                      if (selectedMRT != null && selectedTripNo != null && selectedBusStop != null)
                      BookingConfirmation(
                        KAPDepartureTime: _BusInfo.KAPDepartureTime,
                        CLEDepartureTime: _BusInfo.CLEDepartureTime,
                        SelectedTripNo: selectedTripNo,
                        SelectedMRT: selectedMRT,
                      ),
                      SizedBox(height: 50)
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class BookingConfirmation extends StatefulWidget {
  final List<DateTime> KAPDepartureTime;
  final List<DateTime> CLEDepartureTime;
  final int? SelectedTripNo;
  final String? SelectedMRT;
  //const BookingConfirmation({super.key});

  BookingConfirmation({
    required this.KAPDepartureTime,
    required this.CLEDepartureTime,
    required this.SelectedTripNo,
    required this.SelectedMRT
});

  @override
  State<BookingConfirmation> createState() => _BookingConfirmationState();
}
class _BookingConfirmationState extends State<BookingConfirmation> {
  late Map<String, String?> ColorValues;
  int random_num = 1;
  DateTime now = DateTime.now(); // Initialize with current time
  late Timer timer;
  List<DateTime> DT = [];



  @override
  void initState() {
    super.initState();
    getTime();
    timer = Timer.periodic(Duration(milliseconds: 300), (Timer t) {
      getTime();
    });

    if (widget.SelectedMRT == 'KAP'){
    DT = widget.KAPDepartureTime;
    }
    else if (widget.SelectedMRT == 'CLE'){
    DT = widget.CLEDepartureTime;
    }
  }

  List<Color?> color = [
    Colors.red[100],
    Colors.yellow[200],
    Colors.white,
    Colors.tealAccent[100],
    Colors.orangeAccent[200],
    Colors.greenAccent[100],
    Colors.indigo[100],
    Colors.purpleAccent[100],
    Colors.grey[400],
    Colors.limeAccent[100]
  ];

  Future<void> getTime() async {
    try {
      Response response = await get(
          Uri.parse('https://worldtimeapi.org/api/timezone/Singapore'));
      Map data = jsonDecode(response.body);
      String datetime = data['datetime'];
      String offset = data['utc_offset'].substring(1, 3);
      setState(() {
        now = DateTime.parse(datetime);
        now = now.add(Duration(hours: int.parse(offset)));
      });
    }
    catch (e) {
      print('caught error: $e');
    }
  }

  Color? generateColor() {
    DateTime DepatrueTime = DT[(widget.SelectedTripNo)!-1];
    int departureSeconds = DepatrueTime.hour*3600 + DepatrueTime.minute*60;
    int combinedSeconds = now!.second + departureSeconds;
    int roundedSeconds = (combinedSeconds ~/ 10) * 10;
    DateTime roundedTime = DateTime(
        now!.year, now!.month, now!.day, now!.hour, now!.minute, roundedSeconds
    );
    int seed = roundedTime.millisecondsSinceEpoch ~/ (1000 * 10);
    Random random = Random(seed);
    int syncedRandomNum = random.nextInt(10);
    return color[syncedRandomNum];
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if now is null or not before rendering the color box
    if (now == null) {
      return Container(); // Return an empty container or loading indicator
    }
    return Container(
      width: MediaQuery.of(context).size.width * 0.5,
      height: MediaQuery.of(context).size.width * 0.5,
      color: generateColor() ?? Colors.lightBlue[100],
    );
  }
}


