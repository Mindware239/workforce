import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class BlinkCameraScreen extends StatefulWidget {
  const BlinkCameraScreen({
    super.key,
  });

  @override
  State<BlinkCameraScreen> createState() =>
      _BlinkCameraScreenState();
}

class _BlinkCameraScreenState
    extends State<BlinkCameraScreen> {
  CameraController? _controller;

  late final FaceDetector _faceDetector;

  bool _processing = false;
  bool _capturing = false;

  bool _faceDetected = false;
  bool _faceCentered = false;

  bool _eyesWereClosed = false;

  String _message =
      'Position your face inside the frame';

  @override
  void initState() {
    super.initState();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.12,
      ),
    );

    _initializeCamera();
  }

  // ============================================================
  // CAMERA INITIALIZATION
  // ============================================================

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception(
          'No camera found on this device.',
        );
      }

      CameraDescription camera;

      try {
        camera = cameras.firstWhere(
          (item) =>
              item.lensDirection ==
              CameraLensDirection.front,
        );
      } catch (_) {
        camera = cameras.first;
      }

      debugPrint(
        '📷 Selected camera: ${camera.name}',
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid
                ? ImageFormatGroup.nv21
                : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;

      setState(() {
        _message =
            'Position your face inside the frame';
      });

      await controller.startImageStream(
        _processCameraImage,
      );

      debugPrint(
        '✅ Camera ready',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ Camera initialization error: $e',
      );
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _message =
            'Unable to start camera';
      });
    }
  }

  // ============================================================
  // PROCESS CAMERA FRAME
  // ============================================================

  Future<void> _processCameraImage(
    CameraImage image,
  ) async {
    if (_processing || _capturing) {
      return;
    }

    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    _processing = true;

    try {
      final inputImage = _convertImage(
        image,
        controller.description,
      );

      if (inputImage == null) {
        return;
      }

      final faces =
          await _faceDetector.processImage(
        inputImage,
      );

      if (!mounted || _capturing) {
        return;
      }

      // ========================================================
      // NO FACE
      // ========================================================

      if (faces.isEmpty) {
        _eyesWereClosed = false;

        if (_faceDetected ||
            _faceCentered ||
            _message !=
                'Position your face inside the frame') {
          setState(() {
            _faceDetected = false;
            _faceCentered = false;
            _message =
                'Position your face inside the frame';
          });
        }

        return;
      }

      // ========================================================
      // MORE THAN ONE FACE
      // ========================================================

      if (faces.length > 1) {
        _eyesWereClosed = false;

        setState(() {
          _faceDetected = true;
          _faceCentered = false;
          _message =
              'Only one face should be visible';
        });

        return;
      }

      // ========================================================
      // ONE FACE
      // ========================================================

      final face = faces.first;

      final imageWidth =
          image.width.toDouble();

      final imageHeight =
          image.height.toDouble();

      final faceBox =
          face.boundingBox;

      // ========================================================
      // FACE SIZE
      // ========================================================

      final faceWidth =
          faceBox.width;

      final faceHeight =
          faceBox.height;

      final faceWidthRatio =
          faceWidth / imageWidth;

      final faceHeightRatio =
          faceHeight / imageHeight;

      /*
       * Don't make the size requirement too strict.
       *
       * The user should simply have a reasonably close
       * face to the camera.
       */

      final properSize =
          faceWidthRatio > 0.18 &&
          faceWidthRatio < 0.85 &&
          faceHeightRatio > 0.18;

      // ========================================================
      // FACE CENTER
      // ========================================================

      final faceCenter =
          faceBox.center;

      /*
       * ML Kit's bounding box may use a coordinate space
       * different from the visual portrait preview depending
       * on the sensor orientation.
       *
       * We therefore use a deliberately generous center
       * tolerance instead of requiring an exact center.
       */

      final centerX =
          faceCenter.dx / imageWidth;

      final centerY =
          faceCenter.dy / imageHeight;

      final isHorizontallyCentered =
          centerX > 0.25 &&
          centerX < 0.75;

      final isVerticallyCentered =
          centerY > 0.20 &&
          centerY < 0.80;

      final isCentered =
          properSize &&
          isHorizontallyCentered &&
          isVerticallyCentered;

      // ========================================================
      // UPDATE STATUS
      // ========================================================

      setState(() {
        _faceDetected = true;
        _faceCentered = isCentered;

        if (!properSize) {
          _message =
              'Move a little closer to the camera';
        } else if (!isCentered) {
          _message =
              'Move your face to the center';
        } else {
          _message =
              'Blink once to capture';
        }
      });

      // ========================================================
      // NOT READY
      // ========================================================

      if (!isCentered) {
        _eyesWereClosed = false;
        return;
      }

      // ========================================================
      // EYE DETECTION
      // ========================================================

      final leftEye =
          face.leftEyeOpenProbability;

      final rightEye =
          face.rightEyeOpenProbability;

      /*
       * If ML Kit cannot determine the eyes,
       * don't attempt a capture.
       */

      if (leftEye == null ||
          rightEye == null) {
        debugPrint(
          '⚠️ Eye probabilities unavailable',
        );

        return;
      }

      debugPrint(
        '👁️ left=$leftEye '
        'right=$rightEye',
      );

      // ========================================================
      // BLINK THRESHOLDS
      // ========================================================

      final eyesClosed =
          leftEye < 0.40 &&
          rightEye < 0.40;

      final eyesOpen =
          leftEye > 0.60 &&
          rightEye > 0.60;

      // ========================================================
      // EYES CLOSED
      // ========================================================

      if (eyesClosed) {
        if (!_eyesWereClosed) {
          debugPrint(
            '👁️ Eyes closed',
          );
        }

        _eyesWereClosed = true;
      }

      // ========================================================
      // CLOSED → OPEN
      // ========================================================

      if (_eyesWereClosed &&
          eyesOpen) {
        debugPrint(
          '========================================',
        );

        debugPrint(
          '👁️ BLINK COMPLETED',
        );

        debugPrint(
          '📸 AUTO CAPTURE',
        );

        debugPrint(
          '========================================',
        );

        _eyesWereClosed = false;

        await _capturePhoto();
      }
    } catch (e) {
      debugPrint(
        '❌ Face detection error: $e',
      );
    } finally {
      _processing = false;
    }
  }

  // ============================================================
  // CAPTURE PHOTO
  // ============================================================

  Future<void> _capturePhoto() async {
    if (_capturing) {
      return;
    }

    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    _capturing = true;

    try {
      if (mounted) {
        setState(() {
          _message = 'Capturing...';
        });
      }

      // Stop analysis stream.
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      // Give camera a tiny moment to settle.
      await Future.delayed(
        const Duration(
          milliseconds: 200,
        ),
      );

      final XFile photo =
          await controller.takePicture();

      debugPrint(
        '📸 Captured: ${photo.path}',
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        photo.path,
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ Photo capture error: $e',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _capturing = false;
        _eyesWereClosed = false;
        _message =
            'Unable to capture. Please blink again.';
      });

      try {
        if (!controller.value.isStreamingImages) {
          await controller.startImageStream(
            _processCameraImage,
          );
        }
      } catch (e) {
        debugPrint(
          '❌ Could not restart camera stream: $e',
        );
      }
    }
  }

  // ============================================================
  // CONVERT CAMERA IMAGE
  // ============================================================

  InputImage? _convertImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    final rotation =
        InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );

    if (rotation == null) {
      return null;
    }

    final format =
        InputImageFormatValue.fromRawValue(
      image.format.raw,
    );

    if (format == null) {
      debugPrint(
        '❌ Unsupported camera format: '
        '${image.format.raw}',
      );

      return null;
    }

    final bytes =
        _concatenatePlanes(image);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        rotation: rotation,
        format: format,
        bytesPerRow:
            image.planes.first.bytesPerRow,
      ),
    );
  }

  // ============================================================
  // CONCATENATE PLANES
  // ============================================================

  Uint8List _concatenatePlanes(
    CameraImage image,
  ) {
    final buffer =
        WriteBuffer();

    for (final plane
        in image.planes) {
      buffer.putUint8List(
        plane.bytes,
      );
    }

    return buffer
        .done()
        .buffer
        .asUint8List();
  }

  // ============================================================
  // CAMERA PREVIEW
  // ============================================================

  Widget _buildCameraPreview(
    CameraController controller,
  ) {
    final previewSize =
        controller.value.previewSize;

    if (previewSize == null) {
      return CameraPreview(
        controller,
      );
    }

    /*
     * Camera gives landscape sensor dimensions while the
     * phone is held vertically.
     *
     * Swap width/height so the preview fills the portrait
     * screen correctly without stretching.
     */

    final previewWidth =
        previewSize.height;

    final previewHeight =
        previewSize.width;

    return SizedBox.expand(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: CameraPreview(
              controller,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // OVERLAY
  // ============================================================

  Widget _buildFaceOverlay(
    BuildContext context,
  ) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _FaceOverlayPainter(
          isReady: _faceCentered,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _buildStatus() {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 64,
      child: Center(
        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 200,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: 0.72,
            ),
            borderRadius:
                BorderRadius.circular(
              24,
            ),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              if (_capturing)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),

              if (_capturing)
                const SizedBox(
                  width: 8,
                ),

              Text(
                _message,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final controller =
        _controller;

    return Scaffold(
      backgroundColor:
          Colors.black,
      body: controller == null ||
              !controller
                  .value
                  .isInitialized
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // ==================================================
                // CAMERA
                // ==================================================

                _buildCameraPreview(
                  controller,
                ),

                // ==================================================
                // FACE OVERLAY
                // ==================================================

                _buildFaceOverlay(
                  context,
                ),

                // ==================================================
                // HEADER
                // ==================================================

                Positioned(
                  top: 48,
                  left: 24,
                  right: 24,
                  child: Row(
                    children: [
                      Container(
                        decoration:
                            BoxDecoration(
                          color: Colors.black
                              .withValues(
                            alpha: 0.45,
                          ),
                          shape:
                              BoxShape.circle,
                        ),
                        child:
                            IconButton(
                          onPressed:
                              _capturing
                                  ? null
                                  : () {
                                      Navigator
                                          .of(
                                        context,
                                      ).pop();
                                    },
                          icon:
                              const Icon(
                            Icons.close,
                            color:
                                Colors.white,
                            size: 26,
                          ),
                        ),
                      ),

                      const Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Face Verification',
                              textAlign:
                                  TextAlign
                                      .center,
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize:
                                    21,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                            SizedBox(
                              height: 5,
                            ),
                            Text(
                              'Look at the camera and blink once',
                              textAlign:
                                  TextAlign
                                      .center,
                              style:
                                  TextStyle(
                                color:
                                    Colors.white70,
                                fontSize:
                                    12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        width: 48,
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // STATUS
                // ==================================================

                _buildStatus(),
              ],
            ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    final controller =
        _controller;

    if (controller != null) {
      if (controller
          .value
          .isStreamingImages) {
        controller
            .stopImageStream()
            .catchError(
              (_) {},
            );
      }

      controller.dispose();
    }

    _faceDetector.close();

    super.dispose();
  }
}

// ================================================================
// FACE OVERLAY PAINTER
// ================================================================

class _FaceOverlayPainter
    extends CustomPainter {
  final bool isReady;

  _FaceOverlayPainter({
    required this.isReady,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center =
        Offset(
      size.width / 2,
      size.height / 2,
    );

    final frameWidth =
        size.width *
            0.68;

    final frameHeight =
        frameWidth *
            1.28;

    final rect =
        Rect.fromCenter(
      center: center,
      width: frameWidth,
      height: frameHeight,
    );

    final path =
        Path.combine(
      PathOperation.difference,
      Path()
        ..addRect(
          Offset.zero &
              size,
        ),
      Path()
        ..addOval(rect),
    );

    // Darken everything outside the face area.
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black
            .withValues(
          alpha: 0.48,
        ),
    );

    // Face frame.
    final borderPaint =
        Paint()
          ..color = isReady
              ? Colors.greenAccent
              : Colors.white
          ..style =
              PaintingStyle.stroke
          ..strokeWidth = 3;

    canvas.drawOval(
      rect,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _FaceOverlayPainter oldDelegate,
  ) {
    return oldDelegate.isReady !=
        isReady;
  }
}