import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MusicList(),
      theme: ThemeData.dark(), // Empezamos con un look oscuro profesional
    );
  }
}

class MusicList extends StatefulWidget {
  const MusicList({super.key});
  @override
  State<MusicList> createState() => _MusicListState();
}

class _MusicListState extends State<MusicList> {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  @override
  void initState() {
    super.initState();
    requestPermission();
  }

  // Función para pedir permiso al usuario
  void requestPermission() async {
    // Esto hará que aparezca el cartelito de "Permitir" en tu celular
    bool status = await _audioQuery.permissionsStatus();
    if (!status) {
      await _audioQuery.permissionsRequest();
    }
    setState(() {}); // Actualiza para que el FutureBuilder empiece a buscar
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mi Música")),
      body: FutureBuilder<List<SongModel>>(
        // Buscamos las canciones en el dispositivo
        future: _audioQuery.querySongs(
          sortType: null,
          orderType: null, // Si esto falla, ponlo como null
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
          return ListView.builder(
            itemCount: item.data!.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(item.data![index].title),
                subtitle: Text(
                  item.data![index].artist ?? "Artista desconocido",
                ),
                leading: const Icon(Icons.music_note),
              );
            },
          );
        },
      ),
    );
  }
}
