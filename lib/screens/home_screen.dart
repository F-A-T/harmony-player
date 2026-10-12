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
      backgroundColor: const Color(0xFF141416),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF141416),
        surfaceTintColor: Colors.transparent,
        title: const Text('Harmony Player',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 0.5)),
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
        backgroundColor: const Color(0xFF18181D),
        selectedItemColor: const Color(0xFF8E24AA),
        unselectedItemColor: const Color(0xFF888892),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Ana Sayfa"),
          BottomNavigationBarItem(
              icon: Icon(Icons.library_music_rounded), label: "Kitaplık"),
          BottomNavigationBarItem(
              icon: Icon(Icons.playlist_play_rounded), label: "Listeler"),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: "Arama"),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: "Ayarlar"),
        ],
      ),
    );
  }
}
