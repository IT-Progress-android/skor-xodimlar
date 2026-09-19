import 'package:dio/dio.dart';
import 'package:skore_hodimlar/core/constants/api_constants.dart';
import 'package:skore_hodimlar/core/errors/exceptions.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/features/applications/data/models/ariza_model.dart';

class GetArizalarResponse {
  final List<ArizaModel> arizalar;
  final ArizaSummaryModel summary;
  const GetArizalarResponse({required this.arizalar, required this.summary});
}

abstract class ArizaRemoteDataSource {
  Future<GetArizalarResponse> getArizalar(
    String phone, {
    int? staffId,
    String? status,
  });
  Future<List<ArizaTuriModel>> getArizaTurlari(String phone, {int? staffId});
  Future<ArizaModel> submitAriza(Map<String, dynamic> body);
  Future<String> cancelAriza(String phone, int arizaId, {int? staffId});
}

class ArizaRemoteDataSourceImpl implements ArizaRemoteDataSource {
  final DioClient dioClient;
  ArizaRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<GetArizalarResponse> getArizalar(
    String phone, {
    int? staffId,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{'phone': phone};
      if (staffId != null) queryParams['id'] = staffId;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final response = await dioClient.dio.get(
        ApiConstants.ariza,
        queryParameters: queryParams,
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final body = Map<String, dynamic>.from(response.data as Map);
        final arizalarRaw =
            body['arizalar'] as List? ?? body['data'] as List? ?? [];
        final arizalar = arizalarRaw
            .map(
              (e) => ArizaModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();

        final summaryRaw = body['summary'] is Map
            ? Map<String, dynamic>.from(body['summary'] as Map)
            : <String, dynamic>{};
        final summary = ArizaSummaryModel.fromJson(summaryRaw);

        return GetArizalarResponse(arizalar: arizalar, summary: summary);
      } else if (response.data is List) {
        final arizalar = (response.data as List)
            .map(
              (e) => ArizaModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        return GetArizalarResponse(
          arizalar: arizalar,
          summary: const ArizaSummaryModel(),
        );
      }
      throw ServerException(
        AppLocalizations.trStatic('err_arizalar_load_failed'),
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(AppLocalizations.trStatic('err_no_internet'));
    }
  }

  @override
  Future<List<ArizaTuriModel>> getArizaTurlari(
    String phone, {
    int? staffId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'phone': phone};
      if (staffId != null) queryParams['id'] = staffId;

      final response = await dioClient.dio.get(
        ApiConstants.arizaTurlari,
        queryParameters: queryParams,
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode == 200) {
        List<dynamic> turlarRaw = <dynamic>[];
        if (response.data is Map) {
          final body = Map<String, dynamic>.from(response.data as Map);
          turlarRaw = body['turlar'] as List? ?? body['data'] as List? ?? [];
        } else if (response.data is List) {
          turlarRaw = response.data as List;
        }

        return turlarRaw
            .map(
              (e) =>
                  ArizaTuriModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
      throw ServerException(
        AppLocalizations.trStatic('err_ariza_turlari_load_failed'),
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(AppLocalizations.trStatic('err_no_internet'));
    }
  }

  @override
  Future<ArizaModel> submitAriza(Map<String, dynamic> body) async {
    try {
      final response = await dioClient.dio.post(
        ApiConstants.ariza,
        data: body,
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final resData = (response.data is Map)
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      if ((response.statusCode == 201 || response.statusCode == 200) &&
          (resData['status'] == 'ok' || resData.containsKey('ariza'))) {
        final arizaRaw = resData['ariza'] is Map
            ? Map<String, dynamic>.from(resData['ariza'] as Map)
            : resData;
        return ArizaModel.fromJson(arizaRaw);
      } else {
        String msg =
            resData['message']?.toString() ??
            AppLocalizations.trStatic('err_ariza_submit_failed');
        if (resData['eng_erta'] != null &&
            resData['eng_erta'].toString().isNotEmpty) {
          msg += AppLocalizations.trStatic('ariza_earliest_date_note', {
            'date': resData['eng_erta'].toString(),
          });
        }
        throw ServerException(msg);
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
        AppLocalizations.trStatic('err_ariza_submit_error'),
      );
    }
  }

  @override
  Future<String> cancelAriza(String phone, int arizaId, {int? staffId}) async {
    try {
      final payload = {'phone': phone, 'id': ?staffId, 'ariza_id': arizaId};

      final response = await dioClient.dio.post(
        ApiConstants.arizaBekor,
        data: payload,
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final resData = (response.data is Map)
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};

      if (response.statusCode == 200 && resData['status'] == 'ok') {
        return resData['message']?.toString() ??
            AppLocalizations.trStatic('ariza_cancelled_default');
      } else {
        final msg =
            resData['message']?.toString() ??
            AppLocalizations.trStatic('err_ariza_cancel_failed');
        throw ServerException(msg);
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
        AppLocalizations.trStatic('err_ariza_cancel_error'),
      );
    }
  }
}
