import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

import 'game_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rock Paper Scissors',
      home: PlayerSelectionScreen(),
    );
  }
}

class PlayerSelectionScreen extends StatefulWidget {
  @override
  _PlayerSelectionScreenState createState() => _PlayerSelectionScreenState();
}

class _PlayerSelectionScreenState extends State<PlayerSelectionScreen> {
  List<dynamic> players = [];
  String playerName = '';
  String playerId = '';
  String opponentId = '';
  bool isPlayerAdded = false;
  String gameId = '';

  @override
  void initState() {
    super.initState();
    fetchPlayers();
    // Обновление списка каждые 1 сек
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        fetchPlayers();
      }
    });
  }

  // Получаем список игроков
  Future<void> fetchPlayers() async {
    final response = await http.get(Uri.parse('http://10.0.2.2:8000/players'));

    if (response.statusCode == 200) {
      var responseData = json.decode(response.body);
      setState(() {
        players = responseData;
      });
    }
  }

  // Добавляем игрока
  Future<void> addPlayer() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/join'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'id': id,
        'name': playerName,
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        playerId = id;
        isPlayerAdded = true;
        checkForInvitation();
        startCheckingStatus();
      });
    }
  }

  // Начало игры с выбранным игроком
  Future<void> startGame(String opponentId) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/start_game'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        'player1_id': playerId,
        'player2_id': opponentId,
      }),
    );
  }

  Timer? _statusCheckTimer;

  void startCheckingStatus() {
    _statusCheckTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/player_status/$playerId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'in_game' &&
            data['game_id'] != null &&
            data['opponent_id'] != null) {
          gameId = data['game_id'];
          opponentId = data['opponent_id'];
          _statusCheckTimer?.cancel(); // Останавливаем таймер
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameScreen(
                  gameId: gameId, playerId: playerId, opponentId: opponentId),
            ),
          );
        }
      } else {
        print("Failed to check player status: ${response.statusCode}");
      }
    });
  }

  void invitePlayer(String invitedPlayerId) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/invite_player'),
      body: json.encode({
        'inviter_id': playerId,
        'invitee_id': invitedPlayerId,
      }),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      print("Приглашение отправлено");
    } else {
      print("Ошибка при отправке приглашения");
    }
  }

  void checkForInvitation() {
    Timer.periodic(Duration(seconds: 1), (timer) async {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/player_status/$playerId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'invited') {
          final inviterName = data['inviter_name'];
          final inviterId = data['inviter_id'];

          // Показываем snackbar с предложением сыграть
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$inviterName хочет сыграть с вами'),
              action: SnackBarAction(
                label: 'Согласиться',
                onPressed: () {
                  acceptInvitation(inviterId);
                },
              ),
            ),
          );
        }
      }
    });
  }

  void acceptInvitation(String inviterId) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/start_game'),
      body: json.encode({
        'player1_id': inviterId,
        'player2_id': playerId,
      }),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      print("Игра началась");
    } else {
      print("Ошибка при создании игры");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор игрока'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      playerName = value;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Введите имя',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isPlayerAdded ? null : addPlayer,
                  child: const Text('Ок'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];

                // Не показываем себя в списке
                if (player['id'] == playerId) {
                  return Container(); // Пропускаем отображение
                }

                return ListTile(
                  title: Text(player['name']),
                  trailing: ElevatedButton(
                    onPressed: () {
                      invitePlayer(player['id']);
                    },
                    child: const Text('Играть'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
