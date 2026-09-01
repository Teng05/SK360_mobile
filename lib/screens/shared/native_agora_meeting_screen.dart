import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';

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
  int? _remoteUid;
  int? _localUid;
  String _channel = '';
  String _status = 'Joining meeting...';
  bool _muted = false;
  bool _cameraOff = false;
  bool _joined = false;

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
              _localUid = connection.localUid;
              _status = 'Connected';
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            setState(() {
              _remoteUid = remoteUid;
              _status = 'Participant joined';
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (_remoteUid == remoteUid) {
              setState(() {
                _remoteUid = null;
                _status = 'Waiting for other participants...';
              });
            }
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
      await engine.startPreview();

      setState(() {
        _engine = engine;
        _channel = channel;
        _localUid = uid;
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
    final next = !_cameraOff;
    await _engine?.muteLocalVideoStream(next);
    setState(() => _cameraOff = next);
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
              child: Stack(
                children: [
                  Positioned.fill(child: _remoteView()),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    width: 120,
                    height: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _localView(),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: const Color(0xFF0F172A),
              child: Column(
                children: [
                  Text(
                    _channel.isEmpty ? _status : '$_status  |  $_channel',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
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

  Widget _remoteView() {
    final engine = _engine;
    final remoteUid = _remoteUid;
    if (engine == null || remoteUid == null) {
      return const Center(
        child: Text(
          'Waiting for other participants...',
          style: TextStyle(color: Colors.white70),
        ),
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
        canvas: VideoCanvas(uid: _localUid ?? 0),
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
