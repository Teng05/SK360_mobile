import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';

// Native video meeting UI with participant grid and camera controls.
class NativeAgoraMeetingScreen extends StatefulWidget {
  final int meetingId;
  final String title;

  const NativeAgoraMeetingScreen({
    super.key,
    required this.meetingId,
    required this.title,
  });

  @override
  State<NativeAgoraMeetingScreen> createState() =>
      _NativeAgoraMeetingScreenState();
}

class _NativeAgoraMeetingScreenState extends State<NativeAgoraMeetingScreen> {
  RtcEngine? _engine;
  final List<int> _remoteUids = [];
  final Set<int> _cameraOffUids = {};
  int? _activeSpeakerUid;
  String _channel = '';
  String _status = 'Joining meeting...';
  bool _muted = false;
  bool _cameraOff = false;
  bool _cameraBusy = false;
  bool _joined = false;

  String get _currentUserName {
    final user = MobileApiService.currentUser ?? {};
    final name = [user['first_name'], user['last_name']]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .join(' ')
        .trim();
    return name.isEmpty ? 'You' : name;
  }

  @override
  void initState() {
    super.initState();
    _join();
  }

  @override
  void dispose() {
    _leave(disposeOnly: true);
    super.dispose();
  }

  Future<void> _join() async {
    final permissions = await [Permission.camera, Permission.microphone].request();
    if (permissions.values.any((status) => !status.isGranted)) {
      setState(() => _status = 'Camera and microphone permission are required.');
      return;
    }

    try {
      final token = await MobileApiService.meetingAgoraToken(
        widget.meetingId,
      ).timeout(const Duration(seconds: 12));
      final appId = token['appId']?.toString() ?? '';
      final rtcToken = token['token']?.toString() ?? '';
      final channel = token['channel']?.toString() ?? 'meeting-${widget.meetingId}';
      final uid = int.tryParse(token['uid']?.toString() ?? '') ?? 0;

      if (appId.isEmpty || rtcToken.isEmpty) {
        setState(() => _status = 'Agora token is missing.');
        return;
      }

      final engine = createAgoraRtcEngine();
      setState(() {
        _channel = channel;
        _status = 'Connecting to $channel...';
      });

      await engine.initialize(RtcEngineContext(appId: appId));
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            setState(() {
              _joined = true;
              _status = 'Connected';
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            setState(() {
              if (!_remoteUids.contains(remoteUid)) _remoteUids.add(remoteUid);
              _status = 'Participant joined';
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            setState(() {
              _remoteUids.remove(remoteUid);
              _cameraOffUids.remove(remoteUid);
              if (_activeSpeakerUid == remoteUid) _activeSpeakerUid = null;
              _status = _remoteUids.isEmpty
                  ? 'Waiting for other participants...'
                  : 'Connected';
            });
          },
          onActiveSpeaker: (connection, uid) {
            if (uid == 0 || !_remoteUids.contains(uid)) return;
            setState(() => _activeSpeakerUid = uid);
          },
          onUserMuteVideo: (connection, remoteUid, muted) {
            setState(() {
              if (muted) {
                _cameraOffUids.add(remoteUid);
              } else {
                _cameraOffUids.remove(remoteUid);
              }
            });
          },
          onError: (err, msg) {
            setState(() => _status = 'Agora error: $msg');
          },
        ),
      );

      await engine.setChannelProfile(ChannelProfileType.channelProfileCommunication);
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.enableAudio();
      await engine.enableVideo();
      await engine.enableAudioVolumeIndication(
        interval: 200,
        smooth: 3,
        reportVad: true,
      );
      await engine.startPreview();

      setState(() {
        _engine = engine;
        _channel = channel;
        _joined = true;
        _status = 'Connected';
      });

      unawaited(engine.joinChannel(
        token: rtcToken,
        channelId: channel,
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      ).timeout(const Duration(seconds: 15)).catchError((exception) {
        if (mounted) {
          setState(() {
            _status = 'Join request sent. Waiting for Agora connection...';
          });
        }
      }));
    } on MobileApiException catch (exception) {
      setState(() => _status = exception.message);
    } on TimeoutException {
      setState(() => _status = 'Joining timed out. Check server, token, or network.');
    } catch (exception) {
      setState(() => _status = 'Unable to join meeting: $exception');
    }
  }

  Future<void> _leave({bool disposeOnly = false}) async {
    final engine = _engine;
    if (engine != null) {
      await engine.leaveChannel();
      await engine.release();
    }
    if (!disposeOnly && mounted) Navigator.pop(context);
  }

  Future<void> _toggleMic() async {
    final next = !_muted;
    await _engine?.muteLocalAudioStream(next);
    setState(() => _muted = next);
  }

  Future<void> _toggleCamera() async {
    final engine = _engine;
    if (engine == null || _cameraBusy) return;
    final next = !_cameraOff;
    setState(() => _cameraOff = next);
    _cameraBusy = true;
    try {
      await engine.muteLocalVideoStream(next);
    } catch (_) {
      if (mounted) setState(() => _cameraOff = !next);
    } finally {
      _cameraBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _participantGrid(),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              color: const Color(0xFF0F172A),
              child: Column(
                children: [
                  Text(
                    _channel.isEmpty
                        ? _status
                        : '$_status  |  $_channel',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _showParticipants,
                    icon: const Icon(Icons.people_alt_outlined),
                    label: Text('Participants (${_remoteUids.length + 1})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ControlButton(
                        label: _muted ? 'Unmute' : 'Mute',
                        icon: _muted ? Icons.mic_off : Icons.mic,
                        onTap: _joined ? _toggleMic : null,
                      ),
                      const SizedBox(width: 10),
                      _ControlButton(
                        label: _cameraOff ? 'Camera On' : 'Camera Off',
                        icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                        onTap: _joined ? _toggleCamera : null,
                      ),
                      const SizedBox(width: 10),
                      _ControlButton(
                        label: 'Leave',
                        icon: Icons.call_end,
                        color: AppColors.primaryRed,
                        onTap: () => _leave(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _participantGrid() {
    final orderedRemoteUids = [..._remoteUids];
    if (_activeSpeakerUid != null && orderedRemoteUids.remove(_activeSpeakerUid)) {
      orderedRemoteUids.insert(0, _activeSpeakerUid!);
    }
    final visibleRemoteUids = orderedRemoteUids.take(5).toList();
    final totalTiles = visibleRemoteUids.length + 1;

    if (_engine == null) {
      return const Center(
        child: Text('Joining meeting...', style: TextStyle(color: Colors.white70)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: totalTiles <= 1 ? 1 : totalTiles <= 4 ? 2 : 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: totalTiles,
      itemBuilder: (context, index) {
        final isLocal = index == visibleRemoteUids.length;
        final uid = isLocal ? null : visibleRemoteUids[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              isLocal ? _localView() : _remoteView(uid!),
              Positioned(
                left: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLocal ? _currentUserName : 'Participant $uid',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        Text(
                          isLocal
                              ? 'You'
                              : (_activeSpeakerUid == uid ? 'Speaking' : 'Participant'),
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _remoteView(int remoteUid) {
    final engine = _engine;
    if (engine == null || _cameraOffUids.contains(remoteUid)) {
      return const Center(
        child: Icon(Icons.person, color: Colors.white70, size: 42),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: remoteUid),
        connection: RtcConnection(channelId: _channel),
      ),
    );
  }

  Widget _localView() {
    final engine = _engine;
    if (engine == null || _cameraOff) {
      return Container(
        color: const Color(0xFF1E293B),
        child: const Icon(Icons.person, color: Colors.white70, size: 42),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        // Agora uses UID 0 for the local camera canvas. The token UID is only
        // needed when joining the channel and must not be used for preview.
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  void _showParticipants() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'Participants (${_remoteUids.length + 1})',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const ListTile(
              leading: Icon(Icons.person, color: Colors.white70),
              title: Text('You', style: TextStyle(color: Colors.white)),
            ),
            ..._remoteUids.map(
              (uid) => ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.white70),
                title: Text('Participant $uid', style: const TextStyle(color: Colors.white)),
                trailing: _activeSpeakerUid == uid
                    ? const Text('Speaking', style: TextStyle(color: Colors.greenAccent))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = const Color(0xFF334155),
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
