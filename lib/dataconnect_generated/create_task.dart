part of 'generated.dart';

class CreateTaskVariablesBuilder {
  String title;
  String status;
  String projectId;

  final FirebaseDataConnect _dataConnect;
  CreateTaskVariablesBuilder(this._dataConnect, {required  this.title,required  this.status,required  this.projectId,});
  Deserializer<CreateTaskData> dataDeserializer = (dynamic json)  => CreateTaskData.fromJson(jsonDecode(json));
  Serializer<CreateTaskVariables> varsSerializer = (CreateTaskVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateTaskData, CreateTaskVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateTaskData, CreateTaskVariables> ref() {
    CreateTaskVariables vars= CreateTaskVariables(title: title,status: status,projectId: projectId,);
    return _dataConnect.mutation("CreateTask", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateTaskTaskInsert {
  final String id;
  CreateTaskTaskInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateTaskTaskInsert otherTyped = other as CreateTaskTaskInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateTaskTaskInsert({
    required this.id,
  });
}

@immutable
class CreateTaskData {
  final CreateTaskTaskInsert task_insert;
  CreateTaskData.fromJson(dynamic json):
  
  task_insert = CreateTaskTaskInsert.fromJson(json['task_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateTaskData otherTyped = other as CreateTaskData;
    return task_insert == otherTyped.task_insert;
    
  }
  @override
  int get hashCode => task_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['task_insert'] = task_insert.toJson();
    return json;
  }

  CreateTaskData({
    required this.task_insert,
  });
}

@immutable
class CreateTaskVariables {
  final String title;
  final String status;
  final String projectId;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateTaskVariables.fromJson(Map<String, dynamic> json):
  
  title = nativeFromJson<String>(json['title']),
  status = nativeFromJson<String>(json['status']),
  projectId = nativeFromJson<String>(json['projectId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateTaskVariables otherTyped = other as CreateTaskVariables;
    return title == otherTyped.title && 
    status == otherTyped.status && 
    projectId == otherTyped.projectId;
    
  }
  @override
  int get hashCode => Object.hashAll([title.hashCode, status.hashCode, projectId.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['title'] = nativeToJson<String>(title);
    json['status'] = nativeToJson<String>(status);
    json['projectId'] = nativeToJson<String>(projectId);
    return json;
  }

  CreateTaskVariables({
    required this.title,
    required this.status,
    required this.projectId,
  });
}

