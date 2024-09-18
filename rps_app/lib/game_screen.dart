import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String playerId;
  final String opponentId;

  GameScreen(
      {required this.gameId, required this.playerId, required this.opponentId});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String? winner;
  String? myMove;
  String? opponentMove;
  bool gameFinished = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
  }

  Future<void> makeMove(String playerId, String gameId, String choice) async {
    final url = Uri.parse('http://10.0.2.2:8000/make_move');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'player_id': playerId,
        'game_id': gameId,
        'choice': choice, // "rock", "paper", or "scissors"
      }),
    );

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      print('Response: $responseBody');
      if (responseBody['status'] == 'finished') {
        print('Winner: ${responseBody['winner']}');
      } else {
        print('Waiting for opponent');
        checkGameState();
      }
    } else {
      print('Failed to make move. Status code: ${response.statusCode}');
    }
  }

  void checkGameState() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      final response = await http
          .get(Uri.parse('http://10.0.2.2:8000/game_status/${widget.gameId}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty && data['winner'] != "None") {
          setState(() {
            winner = data['winner'];
            gameFinished = true;
          });
          _timer?.cancel(); // Останавливаем таймер, если победитель найден
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Камень, Ножницы, Бумага'),
      ),
      body: gameFinished
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    winner == "draw"
                        ? "Ничья!"
                        : winner == widget.playerId
                            ? "Вы победили!"
                            : "Вы проиграли!",
                    style: TextStyle(fontSize: 24),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Играть снова'),
                  )
                ],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Сделайте свой ход', style: TextStyle(fontSize: 24)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    buildMoveButton('Камень', 'rock'),
                    buildMoveButton('Ножницы', 'scissors'),
                    buildMoveButton('Бумага', 'paper'),
                  ],
                ),
              ],
            ),
    );
  }

  Widget buildMoveButton(String label, String move) {
    return ElevatedButton(
      onPressed: myMove == null
          ? () => makeMove(widget.playerId, widget.gameId, move)
          : null,
      child: Text(label),
    );
  }
}
