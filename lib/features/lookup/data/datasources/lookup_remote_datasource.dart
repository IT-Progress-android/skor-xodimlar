import 'package:skore_hodimlar/core/network/dio_client.dart';
import 'package:skore_hodimlar/features/lookup/data/models/metadata_model.dart';
import 'package:skore_hodimlar/features/lookup/data/models/tashkilot_model.dart';

abstract class LookupRemoteDataSource {
  Future<List<TashkilotModel>> getTashkilotlar();
  Future<MetadataModel> getMetadata(
    String schoolName,
    String? viloyat,
    String? tuman,
  );
  Future<Map<String, dynamic>> storeStaff(Map<String, dynamic> body);
}

class LookupRemoteDataSourceImpl implements LookupRemoteDataSource {
  final DioClient dioClient;
  LookupRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<TashkilotModel>> getTashkilotlar() async {
    final response = await dioClient.dio.get('/bot/maktablar');
    return (response.data as List)
        .map((e) => TashkilotModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MetadataModel> getMetadata(
    String schoolName,
    String? viloyat,
    String? tuman,
  ) async {
    final query = {'school_name': schoolName};
    if (viloyat != null) query['viloyat'] = viloyat;
    if (tuman != null) query['tuman'] = tuman;
    final response = await dioClient.dio.get(
      '/bot/metadata',
      queryParameters: query,
    );
    return MetadataModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> storeStaff(Map<String, dynamic> body) async {
    final response = await dioClient.dio.post('/bot/staff/store', data: body);
    return response.data as Map<String, dynamic>;
  }
}
