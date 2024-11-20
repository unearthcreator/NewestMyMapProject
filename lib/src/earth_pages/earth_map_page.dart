import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/src/earth_pages/utils/map_config.dart';
import 'package:map_mvp_project/src/earth_pages/utils/map_annotations_manager.dart';
import 'package:map_mvp_project/src/earth_pages/utils/map_gesture_handler.dart';
import 'package:map_mvp_project/src/earth_pages/utils/draggable_annotation_overlay.dart';
import 'package:map_mvp_project/services/error_handler.dart';

class EarthMapPage extends StatefulWidget {
  const EarthMapPage({super.key});
  @override
  EarthMapPageState createState() => EarthMapPageState();
}

class EarthMapPageState extends State<EarthMapPage> {
  late MapboxMap _mapboxMap;
  bool _isMapReady = false;
  late MapAnnotationsManager _annotationsManager;
  late MapGestureHandler _gestureHandler;
  PointAnnotation? _draggingAnnotation;
  Point? _dragPoint;
  bool _isDragging = false;

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    logger.i('Map created.');
    
    final annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _annotationsManager = MapAnnotationsManager(annotationManager);
    
    _gestureHandler = MapGestureHandler(
      mapboxMap: mapboxMap,
      annotationsManager: _annotationsManager,
      context: context,
      onStartDragging: _startDragging,
    );

    setState(() {
      _isMapReady = true;
    });
  }

  void _startDragging(PointAnnotation annotation) {
    logger.i('Starting to drag annotation');
    setState(() {
      _draggingAnnotation = annotation;
      _dragPoint = annotation.geometry;
      _isDragging = true;
    });
  }

  void _handleDrag(DragUpdateDetails details) async {
    if (!_isDragging || _draggingAnnotation == null) return;

    final screenPoint = ScreenCoordinate(
      x: details.globalPosition.dx,
      y: details.globalPosition.dy,
    );

    try {
      final newPoint = await _mapboxMap.coordinateForPixel(screenPoint);
      setState(() {
        _dragPoint = newPoint;
      });
      await _annotationsManager.updateAnnotationPosition(_draggingAnnotation!, newPoint);
    } catch (e) {
      logger.e('Error during drag: $e');
    }
  }

  void _endDrag(DragEndDetails details) {
    logger.i('Ending drag');
    setState(() {
      _draggingAnnotation = null;
      _dragPoint = null;
      _isDragging = false;
    });
  }

  @override
  void dispose() {
    _gestureHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onLongPressStart: (LongPressStartDetails details) {
            logger.i('Long press started');
            final screenPoint = ScreenCoordinate(
              x: details.localPosition.dx,
              y: details.localPosition.dy,
            );
            _gestureHandler.handleLongPress(screenPoint);
          },
          onLongPressEnd: (LongPressEndDetails details) {
            logger.i('Long press ended');
            _gestureHandler.cancelTimer();
          },
          onLongPressCancel: () {
            logger.i('Long press cancelled');
            _gestureHandler.cancelTimer();
          },
          onPanUpdate: _handleDrag,
          onPanEnd: _endDrag,
          child: Scaffold(
            body: Stack(
              children: [
                MapWidget(
                  cameraOptions: MapConfig.defaultCameraOptions,
                  styleUri: MapConfig.styleUri,
                  onMapCreated: _onMapCreated,
                ),
                if (_isMapReady)
                  Positioned(
                    top: 40,
                    left: 10,
                    child: BackButton(
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isDragging && _dragPoint != null)
          DraggableAnnotationOverlay(
            mapboxMap: _mapboxMap,
            initialPosition: _dragPoint!,
            onDragUpdate: (newPosition) {
              // Update the _dragPoint or perform other actions
              _dragPoint = newPosition;
            },
            onDragEnd: () {
              // Perform actions when the drag ends
              _isDragging = false;
            },
          ),
      ],
    );
  }
}