import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/queue_provider.dart';

class WebViewScraper extends StatefulWidget {
  final String url;
  const WebViewScraper({super.key, required this.url});

  @override
  State<WebViewScraper> createState() => _WebViewScraperState();
}

class _WebViewScraperState extends State<WebViewScraper> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1")
      ..addJavaScriptChannel(
        'scraperChannel',
        onMessageReceived: (message) {
          try {
            List<dynamic> items = jsonDecode(message.message);
            List<QueueItem> queueItems = [];
            for (var text in items) {
              if (text is String && text.trim().isNotEmpty) {
                queueItems.add(QueueItem(title: text.trim(), artist: ""));
              }
            }
            if (queueItems.isNotEmpty) {
              context.read<QueueProvider>().addMultipleToQueue(queueItems);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("${queueItems.length} şarkı kuyruğa eklendi!"),
                  backgroundColor: const Color(0xFF8E24AA)));
              Navigator.pop(context); // Tarayıcıyı kapat
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      "Bu sayfada okunabilir liste bulunamadı.\nLütfen listenizin içine girdiğinize emin olun."),
                  backgroundColor: Colors.red));
            }
          } catch (e) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text("Ayrıştırma hatası: $e")));
          }
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _runScraper() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text("Ekranda görünen şarkılar taranıyor... Lütfen bekleyin.")));
    _controller.runJavaScript('''
       var results = [];
       
       if (window.location.href.includes('spotify.com')) {
           var rows = document.querySelectorAll('div[data-testid="tracklist-row"], div[data-encore-id="listRow"], div[role="row"]');
           
           rows.forEach(r => {
              let titleNode = r.querySelector('a[data-testid="internal-track-link"]') || r.querySelector('div.standalone-ellipsis-one-line') || r.querySelector('p[dir="auto"]');
              let title = titleNode ? titleNode.innerText : '';
              
              let artistNodes = r.querySelectorAll('a[href*="/artist/"]');
              let artist = Array.from(artistNodes).map(a => a.innerText).join(', ');
              
              if (!title) {
                 let textBlocks = r.innerText.split('\\n');
                 if (textBlocks.length >= 2) {
                    title = textBlocks[0]; artist = textBlocks[1];
                 }
              }
              if(title) results.push(title + ' - ' + artist);
           });
       } else if (window.location.href.includes('youtube.com')) {
           document.querySelectorAll('ytmusic-responsive-list-item-renderer, ytd-playlist-video-renderer').forEach(el => {
              let text = el.innerText.split('\\n').slice(0, 2).join(' - ');
              if(text && text.trim().length > 3) results.push(text);
           });
       }
       
       scraperChannel.postMessage(JSON.stringify(results));
    ''');
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sistem Tarayıcısı", style: TextStyle(fontSize: 14)),
        backgroundColor: const Color(0xFF181818),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
            tooltip: "Hesaptan Çıkış Yap (Çerezleri Sil)",
            onPressed: () {
              WebViewCookieManager().clearCookies();
              _controller.clearCache();
              _controller.reload();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text("Tüm tarayıcı oturumları ve çerezler temizlendi.")));
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E24AA),
                  foregroundColor: Colors.black),
              icon: const Icon(Icons.download, size: 16),
              label: const Text("Ekranda Ne Varsa Çek",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _runScraper,
            ),
          )
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
