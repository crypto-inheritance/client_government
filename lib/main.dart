import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inheritance Beneficiary',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Inheritance: Government Client'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class TransactionResult {
  late bool success;
  late String result;

  TransactionResult(this.success, this.result);
  @override
  String toString() {
    return "TransactionResult:::\t success: $success\t result: $result";
  }
}

class _MyHomePageState extends State<MyHomePage> {
  late Client httpClient;
  late Web3Client ethereumClient;
  TextEditingController controller = TextEditingController();

  String address = '0x2E81C3cb159DA7750EB59f0e1aFe6cE424E83126';
  String ethereumClientUrl =
      'https://sepolia.infura.io/v3/...';
  String contractName = "Inheritance";
  // String private_key = "";

  int numOfBeneficiaries = 0;
  bool isInheritanceRequestActive = false;
  bool isInheritanceDeadlineActive = false;
  String inheritanceStatus = "Not Active";
  int lastTransactionTime = 0;
  int inheritanceDeadline = 0;
  int inheritanceRequestTime = 0;
  bool loading = false;
  bool inheritanceDeadlineActive = false;
  String lastTransactionResult = "The result will be displayed here";
  String inheritanceRemainingDeadline = "";
  String signatoryAddress = "";


  String government_pk = '...';
  String government_address = '...';

  Future<List<dynamic>> query(String functionName, List<dynamic> args) async {
    DeployedContract contract = await getContract();
    ContractFunction function = contract.function(functionName);
    List<dynamic> result = await ethereumClient.call(
        contract: contract, function: function, params: args);
    return result;
  }


  Future<TransactionResult> transaction(String functionName, String privateKey, List<dynamic> args) async {
    try {
      EthPrivateKey credential = EthPrivateKey.fromHex(government_pk);
      DeployedContract contract = await getContract();
      ContractFunction function = contract.function(functionName);
      dynamic result = await ethereumClient.sendTransaction(
        credential,
        Transaction.callContract(
          contract: contract,
          function: function,
          parameters: args,
        ),
        fetchChainIdFromNetworkId: true,
        chainId: null,
      );
      return TransactionResult(true, result);
    } catch(e){
      print('call function has error ::::: $e');
      return TransactionResult(false, e.toString());
    }
  }

  Future<DeployedContract> getContract() async {
    String abi = await rootBundle.loadString("assets/abi.json");
    String contractAddress = "0x542d67E8d5eCCF1919639366EF9aF312403Bc493";

    DeployedContract contract = DeployedContract(
      ContractAbi.fromJson(abi, contractName),
      EthereumAddress.fromHex(contractAddress),
    );

    return contract;
  }

  Future<void> loadInformation() async {
    loading = true;
    setState(() {});
    List<dynamic> result2 = await query('approvedSignatoryCount', []);
    List<dynamic> result3 = await query('getSignatoryAddresses', []);
    List<dynamic> result4 = await query('inheritanceRequestActive', []);
    List<dynamic> result5 = await query('inheritanceDeadlineActive', []);
    List<dynamic> result8 = await query('inheritanceDeadline', []);
    List<dynamic> result9 = await query('inheritanceRequestTime', []);
    int numOfSignatories = int.parse(result2[0].toString());
    numOfBeneficiaries = result3[0].length + 1 - numOfSignatories;

    isInheritanceRequestActive = result4[0];
    isInheritanceDeadlineActive = result5[0];
    inheritanceDeadline = int.parse(result8[0].toString());
    inheritanceRequestTime = int.parse(result9[0].toString());

    if (!isInheritanceRequestActive && !isInheritanceDeadlineActive){
      inheritanceStatus = "Not Active";
      inheritanceDeadlineActive = false;
    } else if (isInheritanceRequestActive && isInheritanceDeadlineActive){
      inheritanceStatus = "Active";
      inheritanceDeadlineActive = true;
      int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      int passed = now - inheritanceRequestTime;
      int remaining = inheritanceDeadline - passed;
      int hours = remaining ~/ 3600;
      int days = hours ~/ 24;
      hours = hours % 24;
      inheritanceRemainingDeadline = '$days days : $hours hours';
    }else if (!isInheritanceRequestActive && isInheritanceDeadlineActive){
      inheritanceStatus = "Approved";
      inheritanceDeadlineActive = false;
    }else if (isInheritanceRequestActive && !isInheritanceDeadlineActive){
      inheritanceStatus = "Canceled";
      inheritanceDeadlineActive = false;
    }
    lastTransactionResult = "The result will be displayed here";

    loading = false;
    setState(() {});
  }

  Future<void> approveInheritance() async {
    setState(() {lastTransactionResult = "";});
    var result = await transaction("confirmInheritanceRequest", "privateKey", []);
    lastTransactionResult = result.result;
    if(result.success){
      loadInformation();
    }
    print("Confirmed Inheritance");
    setState(() {});
  }

  Future<void> cancelInheritance() async {
    setState(() {lastTransactionResult = "";});
    var result = await transaction("cancelInheritanceRequest", "privateKey", []);
    lastTransactionResult = result.result;
    if(result.success){
      loadInformation();
    }
    print("Requested Inheritance");
    setState(() {});
  }

  void listenToAddSignatoryEvent() async {
    final contract = await getContract();
    print("Listening to the event...");
    var event = contract.event('InheritanceRequested');
    final subscription = ethereumClient.events(FilterOptions.events(contract: contract, event: event)).listen((event) {
      print("event.toString(): ${event.toString()}");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Inheritance Requested by Beneficiary"),
      ));
      loadInformation();
    });
  }


  @override
  void initState() {
    super.initState();
    httpClient = Client();
    ethereumClient = Web3Client(ethereumClientUrl, httpClient);
    loadInformation();
    listenToAddSignatoryEvent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(
              height: 50,
            ),
            const Text(
              "*** Information ***",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            Container(
              margin: const EdgeInsets.all(15.0),
              padding: const EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                  border: Border.all(color:  Colors.black)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text(
                        "Number of Beneficiaries:",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Text(
                        "Inheritance Status:",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                    ],
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        loading
                            ? CircularProgressIndicator()
                            : Text(
                          numOfBeneficiaries.toString(),
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        loading
                            ? CircularProgressIndicator()
                            : Text(
                          inheritanceStatus,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                      ]
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            inheritanceDeadlineActive
                ? const Text(
              "*** Deadline Activated ***",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.red),
            )
                : const SizedBox(
              height: 5,
            ),

            inheritanceDeadlineActive
                ? Container(
              margin: const EdgeInsets.all(15.0),
              padding: const EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                  border: Border.all(color:  Colors.red)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      SizedBox(
                        height: 20,
                      ),
                      Text(
                        "Remaining:",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                    ],
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 20,
                        ),
                        Text(
                          inheritanceRemainingDeadline,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                      ]
                  ),
                ],
              ),
            )
                : const SizedBox(
              height: 5,
            ),
            const SizedBox(
              height: 20,
            ),
            Container(
              margin: const EdgeInsets.all(15.0),
              padding: const EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.black)
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Government Actions",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(
                        width: 20,
                      ),
                      Flexible(

                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(label: Text('Enter private key')),
                        ),
                      ),
                      const SizedBox(
                        width: 20,
                      ),
                      DropdownButton<String>(
                        hint: const Text('Enter from saved'),
                        value: signatoryAddress.isNotEmpty ? signatoryAddress : null,
                        items: <String>['Government Address'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          setState(() {
                            signatoryAddress = value!;
                            controller.text = value;
                          });
                        },
                      ),
                      const SizedBox(
                        width: 20,
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(
                        width: 20,
                      ),
                      ElevatedButton(
                        child: const Text('Approve'),
                        onPressed: () => approveInheritance(),
                      ),
                      const SizedBox(
                        width: 20,
                      ),
                      ElevatedButton(
                        child: const Text('Cancel'),
                        onPressed: () => cancelInheritance(),
                      ),
                      const SizedBox(
                        width: 20,
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  const Divider(
                      color: Colors.black
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Text(
                    lastTransactionResult,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w200),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  const Divider(
                      color: Colors.black
                  ),
                  const SizedBox(
                    height: 10,
                  ),

                ],
              ),
            ),
            const SizedBox(
              height: 70,
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: loadInformation,
        tooltip: 'Increment',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
