import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/p2p_network_service.dart';
import 'chat_screen.dart';

/// 📡 P2P Peers Screen - Управление пирами
class P2PPeersScreen extends StatefulWidget {
  const P2PPeersScreen({super.key});

  @override
  State<P2PPeersScreen> createState() => _P2PPeersScreenState();
}

class _P2PPeersScreenState extends State<P2PPeersScreen> {
  final _p2pService = P2PNetworkService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'P2P Network',
              style: GoogleFonts.firaCode(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _p2pService.peersStream,
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Text(
                  '$count peers connected',
                  style: GoogleFonts.firaCode(
                    fontSize: 11,
                    color: Colors.green.withOpacity(0.8),
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _p2pService.peersStream,
        builder: (context, snapshot) {
          final peers = snapshot.data ?? [];
          
          if (peers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lan,
                    size: 64,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Searching for peers...',
                    style: GoogleFonts.firaCode(
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Make sure you\'re on the same network',
                    style: GoogleFonts.firaCode(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: peers.length,
            itemBuilder: (context, index) {
              final peer = peers[index];
              return _buildPeerCard(peer);
            },
          );
        },
      ),
    );
  }

  Widget _buildPeerCard(Map<String, dynamic> peer) {
    final isOnline = peer['status'] == 'online';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.05),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF0080).withOpacity(0.8),
                const Color(0xFFBD00FF).withOpacity(0.8),
              ],
            ),
          ),
          child: Center(
            child: Text(
              (peer['nodeId'] ?? 'U')[0].toString().toUpperCase(),
              style: GoogleFonts.firaCode(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        title: Text(
          peer['nodeId'] ?? 'Unknown',
          style: GoogleFonts.firaCode(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          peer['address'] ?? '',
          style: GoogleFonts.firaCode(
            fontSize: 11,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chat, color: Color(0xFFFF0080)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      contactName: peer['nodeId'] ?? 'User',
                      contactId: peer['peerId'] ?? '',
                      chatType: ChatType.private,
                      memberCount: 2,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
