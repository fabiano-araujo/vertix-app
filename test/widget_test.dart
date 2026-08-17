import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertix/main.dart';

void main() {
  test('Vertix exposes the application root widget', () {
    const app = VertixApp();

    expect(app, isA<StatelessWidget>());
  });
}
