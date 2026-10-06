import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class CameraPage extends StatefulWidget {
  final File template;
  const CameraPage({super.key, required this.template});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _ready = false;
  bool _saving = false;

  double _opacity = 0.5;
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    final backIndex = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    _currentCameraIndex = backIndex >= 0 ? backIndex : 0;

    await _startController(_currentCameraIndex);
  }

  Future<void> _startController(int index) async {
    await _controller?.dispose();
    _ready = false;
    if (mounted) setState(() {});

    _controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _ready = true;
          _offset = Offset.zero;
          _scale = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('相机初始化失败: $e')),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final current = _cameras[_currentCameraIndex];
    int nextIndex = _cameras.indexWhere(
      (c) => c.lensDirection != current.lensDirection,
    );
    if (nextIndex < 0) nextIndex = (_currentCameraIndex + 1) % _cameras.length;

    _currentCameraIndex = nextIndex;
    await _startController(nextIndex);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final file = await _controller!.takePicture();
      await ImageGallerySaver.saveFile(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到相册')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isFront =
        _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),

          Positioned.fill(
            child: GestureDetector(
              onScaleStart: (d) {
                _baseScale = _scale;
              },
              onScaleUpdate: (d) {
                setState(() {
                  _scale = (_baseScale * d.scale).clamp(0.2, 4.0);
                  _offset += d.focalPointDelta;
                });
              },
              child: Transform.translate(
                offset: _offset,
                child: Transform.scale(
                  scale: _scale,
                  child: Opacity(
                    opacity: _opacity,
                    child: Image.file(widget.template, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 40,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.flip_camera_android, color: Colors.white),
              onPressed: _switchCamera,
              tooltip: isFront ? '切到后置' : '切到前置',
            ),
          ),

          Positioned(
            bottom: 130,
            left: 20,
            right: 20,
            child: Row(
              children: [
                const Icon(Icons.opacity, color: Colors.white),
                Expanded(
                  child: Slider(
                    value: _opacity,
                    min: 0.05,
                    
