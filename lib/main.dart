import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const MusicList(), theme: ThemeData.dark());
  }
}

class MusicList extends StatefulWidget {
  const MusicList({super.key});
  @override
  State<MusicList> createState() => _MusicListState();
}

class _MusicListState extends State<MusicList> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<SongModel> allSongs = [];
  int currentIndex = 0;
  Duration _position = Duration.zero; // El segundo donde va la música
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    requestPermission();

    // ESCUCHADOR PARA AUTO-PLAY
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playNextSong(); // Cuando termina, salta a la siguiente
      }
    });

    _audioPlayer.positionStream.listen((p) {
      setState(() {
        _position = p;
      });
    });

    // Agrega esto para que la barra sepa cuánto dura la canción
    _audioPlayer.durationStream.listen((d) {
      setState(() {
        _duration = d ?? Duration.zero;
      });
    });
  }

  // Función para pedir permiso
  void requestPermission() async {
    bool status = await _audioQuery.permissionsStatus();
    if (!status) {
      await _audioQuery.permissionsRequest();
    }
    setState(() {});
  }

  void _playSong(String? uri) {
    try {
      if (uri != null) {
        _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(uri)));
        _audioPlayer.play();
      }
    } catch (e) {
      debugPrint("Error al reproducir: $e");
    }
  }

  void _playNextSong() {
    if (currentIndex < allSongs.length - 1) {
      setState(() {
        currentIndex++;
      });
      _playSong(allSongs[currentIndex].uri);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // IMPORTANTE: Cerramos el reproductor al salir
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mi Música")),
      body: FutureBuilder<List<SongModel>>(
        future: _audioQuery.querySongs(
          sortType: null,
          orderType: null,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        ),
        builder: (context, item) {
          if (item.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (item.data!.isEmpty) {
            return const Center(child: Text("No se encontró música"));
          }

          allSongs = item.data!; // Guardamos la lista

          return ListView.builder(
            itemCount: item.data!.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(item.data![index].title),
                subtitle: Text(item.data![index].artist ?? "Unknown"),
                leading: const Icon(Icons.music_note),
                onTap: () {
                  setState(() {
                    currentIndex = index;
                  });
                  _playSong(allSongs[currentIndex].uri);
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        height:
            150, // Lo subimos a 150 para que quepa el Slider, el tiempo y los botones
        color: Colors.blueGrey[900],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. BARRA DE PROGRESO (SLIDER)
            Slider(
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              min: 0.0,
              // Si la duración es 0, le ponemos 1.0 para que no explote ni se bloquee
              max: _duration.inMilliseconds.toDouble() > 0
                  ? _duration.inMilliseconds.toDouble()
                  : 1.0,
              value: _position.inMilliseconds.toDouble().clamp(
                0.0,
                _duration.inMilliseconds.toDouble() > 0
                    ? _duration.inMilliseconds.toDouble()
                    : 1.0,
              ),
              onChanged: (value) {
                _audioPlayer.seek(Duration(milliseconds: value.toInt()));
              },
            ),

            // 2. TIEMPOS (MINUTOS Y SEGUNDOS)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_position),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // 3. TÍTULO DE LA CANCIÓN
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Text(
                allSongs.isNotEmpty
                    ? allSongs[currentIndex].title
                    : "No hay canción seleccionada",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),

            // 4. BOTONES DE CONTROL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.skip_previous,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () {
                    if (currentIndex > 0) {
                      setState(() {
                        currentIndex--;
                      });
                      _playSong(allSongs[currentIndex].uri);
                    }
                  },
                ),
                StreamBuilder<PlayerState>(
                  stream: _audioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return IconButton(
                      icon: Icon(
                        playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 45,
                      ),
                      onPressed: () {
                        playing ? _audioPlayer.pause() : _audioPlayer.play();
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.skip_next,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: _playNextSong,
                ),
              ],
            ),
          ],
        ),
      ), // <--- Aquí termina el Container
    );
  }
}
