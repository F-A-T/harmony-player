import 'package:flutter/material.dart';
import 'library_view.dart';
import 'search_view.dart';
import 'discover_view.dart';
import 'playlists_view.dart';
import 'settings_view.dart';
import '../widgets/player_panel.dart';
import 'dart:io';

final GlobalKey<SearchViewState> searchViewKey = GlobalKey<SearchViewState>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _views;

  @override
  void initState() {
    super.initState();
    _views = [
      DiscoverView(onSearchQuery: _handleKeSfetClick),
      const LibraryView(),
      const PlaylistsView(),
      SearchView(key: searchViewKey),
      const SettingsView(),
    ];
  }

  void _handleKeSfetClick(String query) {
    setState(() {
      _currentIndex = 3;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      searchViewKey.currentState?.performSearchFromOutside(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harmony Player',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(child: _views[_currentIndex]),
          const PlayerPanel(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF181818),
        selectedItemColor: const Color(0xFF1DB954),
        unselectedItemColor: const Color(0xFFB3B3B3),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Keşfet"),
          BottomNavigationBarItem(
              icon: Icon(Icons.library_music), label: "Kitaplık"),
          BottomNavigationBarItem(
              icon: Icon(Icons.playlist_play), label: "Listeler"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Arama"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Ayarlar"),
        ],
      ),
    );
  }
}
