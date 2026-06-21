import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';

void main() {
  test('API contract centralizes versioned public endpoint paths', () {
    expect(ApiContract.authLogin, '/api/v1/auth/login');
    expect(ApiContract.leagueRunSubmission, '/api/v1/runs/league');
    expect(ApiContract.knockoutRunSubmission, '/api/v1/runs/knockout');
    expect(ApiContract.authorizationHeader, 'Authorization');
  });
}
