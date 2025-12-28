import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;

// GraphQLエンドポイント
const String graphqlEndpoint = "https://develop.api.samansa.com/graphql";

final graphQLClientProvider = Provider<GraphQLClient>((ref) {
  final httpLink = HttpLink(
    graphqlEndpoint,
    httpClient: _CustomHttpClient(http.Client()),
  );

  return GraphQLClient(
    link: httpLink,
    cache: GraphQLCache(store: HiveStore()),
  );
});

class _CustomHttpClient extends http.BaseClient {
  final http.Client _inner;

  _CustomHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll({
      'X-Anonymous-User-Id': 'tentative-anonymous-user-id',
    });
    return _inner.send(request);
  }
}
