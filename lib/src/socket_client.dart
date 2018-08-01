import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../graphql_flutter_henry_fork.dart';

SocketClient socketClient;

class SocketClient {
  static Future<SocketClient> connect(
    final String endPoint, {
    final List<String> protocols = const [
      'graphql-ws',
    ],
    final Map<String, String> headers = const {
      'content-type': 'application/json',
    },
  }) async {
    return SocketClient(GraphQLSocket(await WebSocket.connect(
      endPoint,
      protocols: protocols,
      headers: headers,
    )));
  }

  final Uuid _uuid = Uuid();
  final GraphQLSocket _socket;

  SocketClient(this._socket) {
    _socket.connectionAck.listen(print);
    _socket.connectionError.listen(print);
    _socket.unknownData.listen(print);
    _socket.write(InitOperation());
  }

  Stream<SubscriptionData> subscribe(final SubscriptionRequest payload) {
    final String id = _uuid.v4();

    final StreamController<SubscriptionData> response =
        StreamController<SubscriptionData>();

    final Stream<SubscriptionComplete> complete = _socket.subscriptionComplete
        .where((message) => message.id == id)
        .take(1);

    final Stream<SubscriptionData> data = _socket.subscriptionData
        .where((message) => message.id == id)
        .takeWhile((_) => !response.isClosed);

    final Stream<SubscriptionError> error = _socket.subscriptionError
        .where((message) => message.id == id)
        .takeWhile((_) => !response.isClosed);

    complete.listen((_) => response.close());
    data.listen((message) => response.add(message));
    error.listen((message) => response.addError(message));

    response.onListen = () => _socket.write(StartOperation(id, payload));
    response.onCancel = () => _socket.write(StopOperation(id));

    return response.stream;
  }
}
