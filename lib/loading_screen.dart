import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({
    Key key,
    @required this.i,
  }) : super(key: key);

  final String i;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blueGrey,
              Colors.green[200],
            ]),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'بِسْمِ اللَّـهِ الرَّحْمَـٰنِ الرَّحِيمِ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
          ),
          SizedBox(
            height: 100,
          ),
          CircularProgressIndicator(),
          SizedBox(
            height: 30,
          ),
          Text(
            'Loading... ( ${i.replaceAll(RegExp(r'[^0-9]'), '')} / 115 )',
            style: TextStyle(fontWeight: FontWeight.bold),
          )
        ],
      ),
    );
  }
}
