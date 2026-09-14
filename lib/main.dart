import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const DjiboutiTaxiApp());
}

class DjiboutiTaxiApp extends StatelessWidget {
  const DjiboutiTaxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Djibouti Go',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      ),
      home: const TaxiHomeScreen(),
    );
  }
}

class TaxiHomeScreen extends StatefulWidget {
  const TaxiHomeScreen({super.key});

  @override
  State<TaxiHomeScreen> createState() => _TaxiHomeScreenState();
}

class _TaxiHomeScreenState extends State<TaxiHomeScreen> {
  final String firebaseUrl = "https://djibouti-go-default-rtdb.firebaseio.com/rides.json";

  bool isDriverMode = false;
  
  // Passager
  String pickupLocation = "Place Ménélik, Centre-Ville";
  String dropoffLocation = "Balbala PK12";
  double passengerPriceOffer = 800.0;
  bool isSending = false;
  String statusMessage = "";

  // Chauffeur
  List<Map<String, dynamic>> availableRides = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (isDriverMode) {
        fetchRidesFromFirebase();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> sendRideToFirebase() async {
    setState(() {
      isSending = true;
      statusMessage = "Envoi de la demande à Firebase...";
    });

    final rideData = {
      "pickup": pickupLocation,
      "dropoff": dropoffLocation,
      "price": passengerPriceOffer,
      "status": "pending",
      "timestamp": DateTime.now().toIso8601String(),
    };

    try {
      final response = await http.post(
        Uri.parse(firebaseUrl),
        body: json.encode(rideData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          statusMessage = "Succès ! Course publiée en direct sur Firebase.";
          isSending = false;
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = "Erreur de connexion : $e";
        isSending = false;
      });
    }
  }

  Future<void> fetchRidesFromFirebase() async {
    try {
      final response = await http.get(Uri.parse(firebaseUrl));
      if (response.statusCode == 200 && response.body != "null") {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<Map<String, dynamic>> loadedRides = [];

        data.forEach((key, ride) {
          if (ride['status'] == 'pending') {
            loadedRides.add({
              "id": key,
              "pickup": ride['pickup'] ?? '',
              "dropoff": ride['dropoff'] ?? '',
              "price": ride['price'] ?? 0,
            });
          }
        });

        setState(() {
          availableRides = loadedRides.reversed.toList();
        });
      }
    } catch (e) {
      // Ignorer
    }
  }

  Future<void> acceptRide(String rideId) async {
    final updateUrl = "https://djibouti-go-default-rtdb.firebaseio.com/rides/$rideId.json";
    try {
      await http.patch(
        Uri.parse(updateUrl),
        body: json.encode({"status": "accepted"}),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Course acceptée !"), backgroundColor: Colors.teal),
      );
      fetchRidesFromFirebase();
    } catch (e) {
      // Ignorer
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isDriverMode ? "Djibouti Go • Chauffeur" : "Djibouti Go • Passager"),
        backgroundColor: isDriverMode ? Colors.teal : Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          Row(
            children: [
              Text(isDriverMode ? "Mode Taxi " : "Mode Client ", style: const TextStyle(fontSize: 12)),
              Switch(
                value: isDriverMode,
                activeColor: Colors.amber,
                onChanged: (val) {
                  setState(() {
                    isDriverMode = val;
                    if (isDriverMode) fetchRidesFromFirebase();
                  });
                },
              )
            ],
          )
        ],
      ),
      body: isDriverMode ? _buildDriverScreen() : _buildPassengerScreen(),
    );
  }

  Widget _buildPassengerScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.local_taxi, size: 70, color: Colors.indigo),
            const SizedBox(height: 10),
            const Text(
              "Commander un Taxi",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: pickupLocation,
              decoration: const InputDecoration(
                labelText: "Lieu de prise en charge",
                prefixIcon: Icon(Icons.my_location, color: Colors.green),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => pickupLocation = val,
            ),
            const SizedBox(height: 15),
            TextFormField(
              initialValue: dropoffLocation,
              decoration: const InputDecoration(
                labelText: "Destination",
                prefixIcon: Icon(Icons.location_on, color: Colors.red),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => dropoffLocation = val,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Votre Prix :", style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => setState(() {
                            if (passengerPriceOffer > 300) passengerPriceOffer -= 100;
                          }),
                        ),
                        Text("${passengerPriceOffer.toInt()} DJF", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                          onPressed: () => setState(() => passengerPriceOffer += 100),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isSending ? null : sendRideToFirebase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Commander le Taxi", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            if (statusMessage.isNotEmpty) ...[
              const SizedBox(height: 15),
              Text(statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDriverScreen() {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Demandes en temps réel", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.teal), onPressed: fetchRidesFromFirebase),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: availableRides.isEmpty
                ? const Center(child: Text("Aucune course disponible pour le moment..."))
                : ListView.builder(
                    itemCount: availableRides.length,
                    itemBuilder: (context, index) {
                      final ride = availableRides[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 3,
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.amber,
                            child: Icon(Icons.person, color: Colors.black),
                          ),
                          title: Text("${ride['pickup']} ➔ ${ride['dropoff']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text("Prix proposé : ${ride['price']} DJF", style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                          trailing: ElevatedButton(
                            onPressed: () => acceptRide(ride['id']),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                            child: const Text("Accepter", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}
