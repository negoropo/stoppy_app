import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';

void main() {
group('ApiContract.isPublicAuthPath', () {
test('recognizes every public authentication path', () {
expect(
ApiContract.isPublicAuthPath(ApiContract.authRegister),
isTrue,
);
expect(
ApiContract.isPublicAuthPath(ApiContract.authLogin),
isTrue,
);
expect(
ApiContract.isPublicAuthPath(ApiContract.authRefresh),
isTrue,
);
});

test('normalizes whitespace and trailing slashes', () {
expect(
ApiContract.isPublicAuthPath(
'  ${ApiContract.authRegister}/  ',
),
isTrue,
);

expect(
ApiContract.isPublicAuthPath(
'  ${ApiContract.authLogin}///  ',
),
isTrue,
);

expect(
ApiContract.isPublicAuthPath(
'  ${ApiContract.authRefresh}//  ',
),
isTrue,
);
});

test('does not classify protected endpoints as public', () {
expect(
ApiContract.isPublicAuthPath(ApiContract.playerProfile),
isFalse,
);
expect(
ApiContract.isPublicAuthPath(ApiContract.leagueSnapshot),
isFalse,
);
expect(
ApiContract.isPublicAuthPath(ApiContract.knockoutStatus),
isFalse,
);
});

test('does not accept absolute authentication URLs', () {
expect(
ApiContract.isPublicAuthPath(
'https://example.com${ApiContract.authLogin}',
),
isFalse,
);
});

test('returns false for blank paths', () {
expect(ApiContract.isPublicAuthPath(''), isFalse);
expect(ApiContract.isPublicAuthPath('   '), isFalse);
});
});
}