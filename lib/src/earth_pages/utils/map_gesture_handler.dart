import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:map_mvp_project/services/error_handler.dart';
import 'package:map_mvp_project/src/earth_pages/utils/map_dialog_handler.dart';
import 'package:map_mvp_project/src/earth_pages/utils/map_annotations_manager.dart';

class MapGestureHandler {
  final MapboxMap mapboxMap;
  final MapAnnotationsManager annotationsManager;
  final BuildContext context;

  Timer? _longPressTimer;
  Timer? _placementDialogTimer;
  Point? _longPressPoint;
  bool _isOnExistingAnnotation = false;
  PointAnnotation? _selectedAnnotation;
  PointAnnotation? _lastPlacedAnnotation;
  bool _isDragging = false;

  MapGestureHandler({
    required this.mapboxMap,
    required this.annotationsManager,
    required this.context,
  });

  Future<void> handleLongPress(ScreenCoordinate screenPoint) async {
    try {
      final features = await mapboxMap.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenPoint),
        RenderedQueryOptions(layerIds: [annotationsManager.annotationLayerId]),
      );
      
      logger.i('Features found: ${features.length}');
      
      _longPressPoint = await mapboxMap.coordinateForPixel(screenPoint);
      _isOnExistingAnnotation = features.isNotEmpty;
      
      if (!_isOnExistingAnnotation && _longPressPoint != null) {
        // Handle new annotation creation
        logger.i('No annotation at tap location. Adding new annotation.');
        final newAnnotation = await annotationsManager.addAnnotation(_longPressPoint!);
        _lastPlacedAnnotation = newAnnotation;
        _startPlacementDialogTimer();
      } else if (_isOnExistingAnnotation && _longPressPoint != null) {
        _selectedAnnotation = await annotationsManager.findNearestAnnotation(_longPressPoint!);
        if (_selectedAnnotation != null) {
          _startDragTimer();
        }
      }
    } catch (e) {
      logger.e('Error during feature query: $e');
    }
  }

  void _startDragTimer() {
    _longPressTimer?.cancel();
    logger.i('Starting drag timer');
    
    _longPressTimer = Timer(const Duration(seconds: 1), () {
      logger.i('Drag timer completed - annotation can now be dragged');
      _isDragging = true;
    });
  }

  Future<void> handleDrag(ScreenCoordinate screenPoint) async {
    if (!_isDragging || _selectedAnnotation == null) return;

    try {
      final newPoint = await mapboxMap.coordinateForPixel(screenPoint);
      await annotationsManager.updateVisualPosition(_selectedAnnotation!, newPoint);
    } catch (e) {
      logger.e('Error during drag: $e');
    }
  }

  void endDrag() {
    if (_isDragging && _selectedAnnotation != null) {
      logger.i('Ending drag');
      _isDragging = false;
      _selectedAnnotation = null;
    }
  }

  void _startPlacementDialogTimer() {
    _placementDialogTimer?.cancel();
    logger.i('Starting placement dialog timer');
    
    _placementDialogTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final currentAnnotation = _lastPlacedAnnotation;
        if (currentAnnotation == null) return;

        final shouldKeepAnnotation = await MapDialogHandler.showNewAnnotationDialog(context);
        
        if (!shouldKeepAnnotation) {
          await annotationsManager.removeAnnotation(currentAnnotation);
        }
      } catch (e) {
        logger.e('Error in placement dialog timer: $e');
      } finally {
        _lastPlacedAnnotation = null;
      }
    });
  }

  void cancelTimer() {
    logger.i('Cancelling timers');
    _longPressTimer?.cancel();
    _placementDialogTimer?.cancel();
    _longPressTimer = null;
    _placementDialogTimer = null;
    _longPressPoint = null;
    _selectedAnnotation = null;
    _lastPlacedAnnotation = null;
    _isOnExistingAnnotation = false;
    _isDragging = false;
  }

  void dispose() {
    cancelTimer();
  }

  bool get isDragging => _isDragging;
  PointAnnotation? get selectedAnnotation => _selectedAnnotation;
}